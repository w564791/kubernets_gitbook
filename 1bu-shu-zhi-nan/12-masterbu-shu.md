# 部署高可用 kubernetes master 集群

kubernetes master 节点包含的组件：

* kube-apiserver
* kube-scheduler
* kube-controller-manager

目前这三个组件需要部署在同一台机器上。

* `kube-scheduler`、`kube-controller-manager`和`kube-apiserver`三者的功能紧密相关；同时只能有一个`kube-scheduler`、`kube-controller-manager`
* 进程处于工作状态，如果运行多个，则需要通过选举产生一个 leader；

此处记录部署一个三个节点的高可用 kubernetes master 集群步骤,后续创建一个`load balancer`\(`nginx,`部署在`k8s-1`上\)来代理访问`kube-apiserver` 的请求

下载响应版本的二进制包

此处使用的是[v1.6.6](https://github.com/w564791/kubernetes/archive/v1.6.6.tar.gz)版本

```
# wget https://github.com/kubernetes/kubernetes/archive/v1.6.6.tar.gz
# tar -xf v1.6.6.tar.gz && cd kubernetes-1.6.6/cluster/ &&echo "v1.6.6" > ../version
# ./get-kube-binaries.sh
...

```

设置环境变量\(略\);

再次确认下证书:





