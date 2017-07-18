* K8S架构图

![](/assets/import.png)组件名词解释:

**\[Master\]**

* scheduler:集群种的调度器,负责Pod在集群种节点的调度分配
* controller-manager:集群内部的管理控制中心,其主要目的是实现Kubernetes集群的故障检测和恢复自动化工作
* api-server:提供kubernetes集群的API调用,为集群资源对象的唯一操作入口,其他所有组件都必须通过它提供的API来操作资源数据,通过对相关数据”全量查询”+”变化监听”,这些组件可以很实时的完成相关的业务功能.

* etcd:一个高可用的K/V键值对存储和服务发现系统,用于持久化存储集群种所有的资源对象,例如集群种的Node,Service,Pod,RC,Namespace等,关于master集群,集群使用lease-lock漂移来实现leader选举\(原文:we are going to use a lease-lock in the API to perform master election\)

**\[Node\]**:

* docker-daemon: docker
* proxy:实现Service的代理及软件模式的负载均衡器
* kubelet:负责本节点上的Pod的创建,修改,监控,销毁等全生命周期管理,同事定时上报本节点的状态信息到API Server
* flannel: 实现夸主机的容器网络的通信



