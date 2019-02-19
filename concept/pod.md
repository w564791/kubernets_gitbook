## 理解Pod

Pod是kubernetes中你可以创建和部署的最小也是最简单位。一个Pod代表着集群中运行的一个进程。

Pod就像是豌豆荚一样，它由一个或者多个容器组成（例如Docker容器），它们共享容器存储、网络和容器运行配置项。Pod中的容器总是被同时调度，有共同的运行环境。你可以把单个Pod想象成是运行独立应用的“逻辑主机”——其中运行着一个或者多个紧密耦合的应用容器——在有容器之前，这些应用都是运行在几个相同的物理机或者虚拟机上。

Pod中封装着应用的容器（有的情况下是好几个容器），存储、独立的网络IP，管理容器如何运行的策略选项。Pod代表着部署的一个单位：kubernetes中应用的一个实例，可能由一个或者多个容器组合在一起共享资源。

> [Docker](https://www.docker.com)是kubernetes中最常用的容器运行时，但是Pod也支持其他容器运行时。

Pods are employed a number of ways in a Kubernetes cluster, including:

在Kubrenetes集群中Pod有如下两种使用方式：

* **一个Pod中运行一个容器**。“每个Pod中一个容器”的模式是最常见的用法；在这种使用方式中，你可以把Pod想象成是单个容器的封装，kuberentes管理的是Pod而不是直接管理容器。
* **在一个Pod中同时运行多个容器**。一个Pod中也可以同时封装几个需要紧密耦合互相协作的容器，它们之间共享资源。这些在同一个Pod中的容器可以互相协作成为一个service单位——一个容器共享文件，另一个“sidecar”容器来更新这些文件。Pod将这些容器的存储资源作为一个实体来管理。

每个Pod都是应用的一个实例。如果你想平行扩展应用的话（运行多个实例），你应该运行多个Pod，每个Pod都是一个应用实例。在Kubernetes中，这通常被叫称为是replication。

一个Pod种的应用容器共享同一组资源:

* PID命名空间:  pod有独立的pid命名空间,这相对于宿主机,pid是可以与宿主机重复的;



| PID命名空间共享: 即Pod种的不同容器内程序可以看到其他容器程序的进程ID,Pod中的容器共享IP地址和端口号，它们之间可以通过localhost互相发现,pid命名空间共享在K8S1.8之前默认开启,并且需要docker 版本高于或者等于1.13.1 |
| :----------------------------------------------------------- |
|                                                              |

* 网络命名空间: Pod种的多个容器能够访问同一个IP和端口范围,每个Pod都会被分配一个唯一的IP地址。Pod中的所有容器共享网络空间，包括IP地址和端口,Pod中的容器与外界通信时，必须分配共享网络资源（例如使用宿主机的端口映射）;

* IPC命名空间: Pod种的多个容器能使用SystemV IPC或POSIX消息队列进行通信

* UTS命名空间: Pod种的多个容器共享一个主机名

* Volumes\(共享存储卷\):Pod种的各个容器可以访问在Pod级别定义的Volumes,Volume跟pod有相同的生命周期（当其UID存在的时候）。当Pod因为某种原因被删除或者被新创建的相同的Pod取代，它相关的东西（例如volume）也会被销毁和再创建一个新的volume。

## 使用Pod

你很少会直接在kubernetes中创建单个Pod。因为Pod的生命周期是短暂的，用后即焚的实体。当Pod被创建后（不论是由你直接创建还是被其他Controller），都会被Kuberentes调度到集群的Node上。直到Pod的进程终止、被删掉、因为缺少资源而被驱逐、或者Node故障之前这个Pod都会一直保持在那个Node上。

> 注意：重启Pod中的容器跟重启Pod不是一回事。Pod只提供容器的运行环境并保持容器的运行状态，重启容器不会造成Pod重启。

Pod不会自愈。如果Pod运行的Node故障，或者是调度器本身故障，这个Pod就会被删除。同样的，如果Pod所在Node缺少资源或者Pod处于维护状态，Pod也会被驱逐。Kubernetes使用更高级的称为Controller的抽象层，来管理Pod实例。虽然可以直接使用Pod，但是在Kubernetes中通常是使用Controller来管理Pod的。

## Pod的动机

### 管理

Pod是一个服务的多个进程的聚合单位，pod提供这种模型能够简化应用部署管理，通过提供一个更高级别的抽象的方式。Pod作为一个独立的部署单位，支持横向扩展和复制。共生（协同调度），命运共同体（例如被终结），协同复制，资源共享，依赖管理，Pod都会自动的为容器处理这些问题。

## Pod的终止

因为Pod作为在集群的节点上运行的进程，所以在不再需要的时候能够优雅的终止掉是十分必要的（比起使用发送KILL信号这种暴力的方式）。用户需要能够放松删除请求，并且知道它们何时会被终止，是否被正确的删除。用户想终止程序时发送删除pod的请求，在pod可以被强制删除前会有一个优雅删除的时间，会发送一个TERM请求到每个容器的主进程。一旦超时，将向主进程发送KILL信号并从API server中删除。如果kubelet或者container manager在等待进程终止的过程中重启，在重启后仍然会重试完整的优雅删除阶段。

示例流程如下：

1. 用户发送删除pod的命令，默认优雅删除时期是30秒；
2. 在Pod超过该优雅删除期限后API server就会更新Pod的状态为“dead”；
3. 在客户端命令行上显示的Pod状态为“terminating”；
4. 跟第三步同时，当kubelet发现pod被标记为“terminating”状态时，开始停止pod进程：
   1. 如果在pod中定义了preStop hook，在停止pod前会被调用。如果在优雅删除期限过期后，preStop hook依然在运行，第二步会再增加2秒的优雅时间；
   2. 向Pod中的进程发送TERM信号；
5. 跟第三步同时，该Pod将从该service的端点列表中删除，不再是replication controller的一部分。关闭的慢的pod将继续处理load balancer转发的流量；
6. 过了优雅周期后，将向Pod中依然运行的进程发送SIGKILL信号而杀掉进程。
7. Kublete会在API server中完成Pod的的删除，通过将优雅周期设置为0（立即删除）。Pod在API中消失，并且在客户端也不可见。

删除优雅周期默认是30秒。 `kubectl delete`命令支持 `—grace-period=<seconds>` 选项，允许用户设置自己的优雅周期时间。如果设置为0将强制删除pod。在kubectl&gt;=1.5版本的命令中，你必须同时使用 `--force` 和 `--grace-period=0` 来强制删除pod。

删除驱逐的pod

````shell
kubectl get pods --all-namespaces -ojson | jq -r '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | .metadata.name + " " + .metadata.namespace' | xargs -n2 -l bash -c 'kubectl delete pods $0 --namespace=$1'
````



