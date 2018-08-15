[Node affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature) ,描述的是一组设置在node上的属性,将pod吸附到node上,Taints恰好相反,其让node排斥pod,除非pod带有其指定的属性.

Taints和Tolerations一起工作确保pod不被调度到不适当的node上,一个ndoe上可以设置一个或多个taints,其标记这个node不能接受任何不能容忍taints的pod,当Tolerations被应用于pod时,允许pod被调度到具有匹配污点的节点上.但不做强制要求.

# 概念

为node添加一个taint属性可以使用 [kubectl taint ](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#taint),例如:

```
$ kubectl taint nodes node1 name=tom:NoSchedule
```

这将在node1上设置key为name,value为tom,effect为NoSchedule 的taint,这意味着pod将不能调度到node1上,除非他具有匹配的toleration

使用如下命令移除该taint

```
$ kubectl taint nodes node1 name:NoSchedule-
```

当设置了taint时,可以在pod中设置toleration,以容忍该taint,如下3种\(精度从上到下依次降低\)tilerations都匹配上面创建的taint,此时该pod将能调度到node1上\(但不是必须\),第三种不建议,此时可能会调度到任何具有effect为NoSchedule的节点上.

```
tolerations:
- key: "name"
  operator: "Equal"
  value: "tom"
  effect: "NoSchedule"
```

```
tolerations:
- key: "name"
  operator: "Exists"
  effect: "NoSchedule"
```

```
tolerations:
- operator: "Exists"
  effect: "NoSchedule"
```

当toleration的key和effects都与taint匹配,并且:

* operator为Exists\(这种情况下不应该指定value\) ,或者

* operator为Equal,此时value相等

operator未指定时默认为Equal

NOTE: 这里有2处需要特别注意:

* 如果key为空并且operator为Equal时将匹配所有key,value和effect将容忍所有

```
tolerations:
- operator: "Exists"
```

* 当effect为空时将匹配所有effects

```
tolerations:
- key: "key"
  operator: "Exists"
```

上面的例子使用了NoSchedule 的effect,另外,你也能使用PreferNoSchedule的effect,这相对于NoSchedule来说,是一个偏向柔和的,或者说偏向软限制的,系统将避免放置一个不能容忍该污点的pod到该node上,但这不是必须的.第三种effect是NoExecute,稍后描述

你可以在一个node上设置多个taint,也能在一个pod中设置多个toleration,kubernetes处理多个taint和toleration就像是一个过滤器,从node上所有的taint开始,忽略那些已经匹配了toleration.当在pod上,其余未被忽略的的taint在pod上有的指定effect时:

* 如果最新的未被忽略的taint具有effect为NoSchedule时,kubernetes不会调度pod到该node上
* 如果未被忽略的taint没有effect为NoSchedule,但是最新的未被忽略的taint具有effect为PreferNoSchedule,kubernetes会尝试不将pod调度到该节点\(还是有可能调度到这里\)
* 如果此时最新的未被忽略的taint具有effect为NoExecute时,pod将会被从该节点驱散\(如果pod运行在该节点的话\),并且不会调度到该节点上.

比如,想想一个node上有如下taint:

```
kubectl taint nodes node1 key1=value1:NoSchedule
kubectl taint nodes node1 key1=value1:NoExecute
kubectl taint nodes node1 key2=value2:NoSchedule
```

pod具有2个tolerations

```
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute"
```

在这个例子中,pod将不会调度到该node上,因为没有第三个toleration匹配第三个taint,但是其如果已经运行在节点上,那么pod将继续在节点上运行

一般情况下,如果effect为NoExecute被添加到一个node上时,如果pod没有响应匹配的toleration,此时pod将会被立即驱散,任何匹配改taint的pod将会继续运行在node上,当effect为NoExecute时,此时指定选项tolerationSeconds,指定taint被添加到node时,pod将持在节点上续运行多长时间

例如:

```
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute"
  tolerationSeconds: 3600
```

意味着当该pod运行在node上,并且匹配taint时,pod将继续在节点上运行3600秒,之后被驱散,如果期间taint被删除,那么pod将不会被驱散

# 案例

Taints 和tolerations非常灵活的驾驭pod从node驱散或者远离node,一些用例如下:

* **Dedicated Nodes **



