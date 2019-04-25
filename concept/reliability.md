原文来自[**kubernetes-reliability**](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/kubernetes-reliability.md),译者对原文不合理的地方有删减

# 概览

类似于`kubernetes`的分布式系统旨在应对故障发生,有关`kubernetes`HA的更多文章,参阅[Building High-Availability Clusters](https://kubernetes.io/docs/admin/high-availability/)

为了获得更加简单的步骤,我们将跳过大部分内容来描述`kubelet`<->`Controller Manager`之间的通信

默认情况下,正常的行为如下:

1. `kubelet`定期向`apiserver`发送其状态,发送周期由`--node-status-update-frequency`参数指定,默认值是10s
2. `Kubernetes Controller Manager`定期的检查`kubelet`状态,该参数由`–-node-monitor-period`参数指定,默认值5秒s
3. `Kubernetes Controller Manager`对`kubelet`状态更新有一个容忍值,如果`kubelet`在这个容忍值内更新状态,那么`Kubernetes Controller Manager`认为`kubelet`状态有效.容忍值参数由`--node-monitor-grace-period`指定,默认值为40s

*`Kubernetes Controller Manager`和`kubelet`异步工作,这意味着延迟可能包含网络延迟,`API Server`延迟,`etcd`延迟,节点负载等引起的延迟,所以如果设置`--node-status-update-frequency`参数为5秒时,那么当`etcd`无法将数据提交到仲裁节点时,它可能会在`etcd`中等待6-7秒甚至更长才能被呈现*

# 失败

`kubelet`将尝试发送`nodeStatusUpdateRetry` ,当前`nodeStatusUpdateRetry` 在[kubelet.go](https://github.com/kubernetes/kubernetes/blob/release-1.5/pkg/kubelet/kubelet.go#L102).中设置为5

`kubelet`将使用 [tryUpdateNodeStatus](https://github.com/kubernetes/kubernetes/blob/release-1.5/pkg/kubelet/kubelet_node_status.go#L312)方法发送状态.`kubelet`使用`golang`的http.Client()方法,但是没指定超时时长,因此当在`apiserver`过载时TCP连接会造成一些问题.



因此,这里尝试使用`nodeStatusUpdateRetry` 乘以 `--node-status-update-frequency`的值设置node状态.

在同时`Kubernetes Controller Manager`每隔`--node-monitor-period`设置的时间检查`nodeStatusUpdateRetry`设置的次数,经过`--node-monitor-grace-period`设定的时间将认为node不健康,`Kubernetes Controller Manager`通过`--pod-eviction-timeout`设置pod移除的容忍值.

同时`Kube Proxy`watch API server,一旦pod被移除,那么集群中所有`kube proxy`将更新其节点上的`iptables`规则,移除相应的`endpoint`,这使得请求无法被发送到故障节点的pod


# 针对不同案例的建议

## 快速更新以及快速反应



| 参数                             | 默认值 | 建议值 | 组件                 |
| -------------------------------- | ------ | ------ | -------------------- |
| `--node-status-update-frequency` | 10s    | 4s     | `kubelet`            |
| `--node-monitor-period`          | 5s     | 2s     | `controller manager` |
| `--node-monitor-grace-period`    | 40s    | 20s    | `controller manager` |
| `--pod-eviction-timeout`         | 5m     | 30s    | `controller manager` |

在该建议参数中,ep将在node认为挂掉后(第20秒)后移除(译者测试过程中`--pod-eviction-timeout`参数失效,[issue72395](https://github.com/kubernetes/kubernetes/issues/72395)处于open状态),该建议会对`etcd`造成一定的开销

如果集群中有1000个节点,那么在1分钟内会有15000次node节点更新,这需要考虑使用大型的`etcd`集群活专用节点.

*如果我们计算尝试次数,除法将给出5,但是实际上`nodeStatusUpdateRetry`尝试都是3-5次,由于所有组件的延迟,尝试总次数将在15-25之间变化*

## 中等更新和平均反应

| 参数                             | 默认值 | 建议值 |
| -------------------------------- | ------ | ------ |
| `--node-status-update-frequency` | 10s    | 20s    |
| `--node-monitor-period`          | 5s     | 5s     |
| `--node-monitor-grace-period`    | 40s    | 2m     |
| `--pod-eviction-timeout`         | 5m     | 1m     |

在该建议参数中,`kubelet`每20秒上报状态,在`Kubernetes Controller Manager`考虑节点不健康前,1分钟后驱逐所有pod

此处情况适用于中等环境,因为1000个节点每分钟需要对`etcd`进行3000次更新



## 低更新和慢反应



| 参数                             | 默认值 | 建议值 |
| -------------------------------- | ------ | ------ |
| `--node-status-update-frequency` | 10s    | 1m     |
| `--node-monitor-period`          | 5s     | 5s     |
| `--node-monitor-grace-period`    | 40s    | 5m     |
| `--pod-eviction-timeout`         | 5m     | 1m     |

在该建议参数中,`kubelet`将在每分钟上报状态,5分钟后,`Kubernetes Controller Manager`将节点设置为不健康

在译者测试中(`kubernetes` 集群版本1.13.4),`--pod-eviction-timeout`在设置后无效,pod依然会在5分钟后重新调度,参见[issue72395](https://github.com/kubernetes/kubernetes/issues/72395)

可以有不同的组合，例如快速更新和慢反应以满足特定情况。

PS: `--node-status-update-frequency`在未来可能弃用,在`kubelet --config`文件中使用`nodeStatusUpdateFrequency`字段