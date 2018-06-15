官网:[ https://containerd.io/](https://containerd.io/)

官方github: [https://github.com/containerd/containerd](https://github.com/containerd/containerd)

containerd的优势:

FROM [_https://blog.fleeto.us/post/kubernetes-containerd-integration-goes-ga/_](https://blog.fleeto.us/post/kubernetes-containerd-integration-goes-ga/)

原文：

[Kubernetes Containerd Integration Goes GA](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/)

作者：

* [Lantao Liu](https://www.linkedin.com/in/liu-lantao-96a97351)
* [Mike Brown](https://www.twitter.com/mikebrow)

Containerd 1.1 支持 Kubernetes 1.10 及以上版本，支持 Kubernetes 的所有特性。目前在 Kubernetes 的测试设施中，Containerd 在

[Google 云平台](https://cloud.google.com/)上的测试覆盖已经和 Docker 集成持平了。（参见：[Test Dashboard](https://k8s-testgrid.appspot.com/sig-node-containerd)）。

### 架构提升

Kubernetes 的 Containerd 集成架构有两次重大改进，每一次都让整个体系更加稳定和高效。

Containerd 1.0 - CRI-Containerd（已终止）

![](/assets/asa1import.png)Containerd 1.0 中，需要一个叫做 cri-containerd 的守护进程，他的功能是提供 Kubelet 和 Containerd 之间的互操作支持。Cri-Containerd 处理来自 Kubelet 的[容器运行时接口（CRI）](https://kubernetes.io/blog/2016/12/container-runtime-interface-cri-in-kubernetes/)服务请求，并使用 containerd 来管理容器和容器的镜像。对比之前的 Docker CRI 实现（[Dockershim](https://github.com/kubernetes/kubernetes/tree/v1.10.2/pkg/kubelet/Dockershim)），他清理了整个体系中的一些多余部分。

然而 Cri-containerd 和 Containerd 1.0 还是两个不同的守护进程，相互之间使用 gRPC 进行通信。额外进程给用户的理解和部署都造成了麻烦，并引入了不必要的通信开支。

Containerd 1.1 - CRI 插件（目前）

![](/assets/dasa1import.png)在 Containerd 1.1 中，Cri-containerd 守护进程进行了重构，成为了 Containerd 的 CRI 插件。CRI 插件处于 Containerd 1.1 内部，缺省启用。和 Cri-containerd 不同，CRI 插件和 Containerd 之间通过直接的程序调用来协同工作。新架构让这一产品更加稳定高效，去除了过程中的 gRPC 开销。用户现在可以直接使用 Containerd 1.1 来支撑 Kubernetes，不再需要 Cri-containerd 守护进程。

## 性能 {#性能}

Containerd 1.1 的一个主要目标就是提高性能。这里的性能主要指的是 Pod 启动延迟以及守护进程的资源使用情况。

下面的结果是 Containerd 1.1 和 Docker 18.03 CE 之间的对比。Containerd 1.1 集成使用了内置其中的 CRI 插件；Docker 18.03 CE 集成使用的是 Dockershim。

下面的结果是使用 Kubernetes 节点性能 Benchmark 生成的，这个 Benchmark 工具是[Kubernetes 节点端到端测试](https://github.com/kubernetes/community/blob/master/contributors/devel/e2e-node-tests.md)的一部分。绝大多数的 Containerd 测试结果都是可以在[节点性能 Dashboard](http://node-perf-dash.k8s.io/)上进行公开访问的。

### Pod 启动延迟 {#pod-启动延迟}

“105 pod batch startup benchmark” 结果显示，相对 Docker 18.03 CE 的 dochershim 集成来说，Containerd 1.1 的集成的延迟时间更短（越低越好）。

![](/assets/podstart.png)

## CPU 和内存 {#cpu-和内存}

在 105 个 Pod 的稳定状态下，Containerd 1.1 集成消耗的 CPU 和内存都比 Docker 18.03 CE 的 Dockershim 集成要少。这个结果和节点上运行的 Pod 数量关系紧密，之所以选择 105 这个数字，是因为这是目前每节点上运行 Pod 的缺省数量上限。

如下图所示，对比 Docker 18.03 CE 的 Dockershim 集成，Containerd 1.1 集成的 Kubelet CPU 占用降低了 30.89%，容器运行时 CPU 消耗降低了 68.13%，Kubelet 实际使用内存（RSS）降低了 11.30%，容器运行时 RSS 降低了 12.78%。

![](/assets/cpu usage.png)

![](/assets/memoryimport.png)

## crictl {#crictl}

容器运行时命令行接口（CLI）对系统和应用的排错来说是个有用的工具。如果用 Docker 作为 Kubernetes 的容器运行时，系统管理员有时候需要登录到 Kubernetes 节点上去运行 Docker 命令，以便收集系统和应用的信息。例如使用`docker ps`和`docker inspect`检查应用的进程情况，`docker images`列出节点上的镜像，或者`docker info`来检查容器运行时的配置等。

对 Containerd 和所有其他的 CRI 兼容的容器运行时，尤其是 Dockershim 来说，我们推荐使用`crictl`作为 Docker CRI 的继任者，用于 Kubernetes 节点上 pod、容器以及镜像的除错工具。

`crictl`在 Kubernetes 节点除错方面，提供了类似 Docker CLI 的使用体验， 并且`crictl`能够支持所有 CRI 兼容的容器运行时。这一项目存放于[kubernetes-incubator/cri-tools](https://github.com/kubernetes-incubator/cri-tools)，目前版本是[v1.0.0-beta.1](https://github.com/kubernetes-incubator/cri-tools/releases/tag/v1.0.0-beta.1)。`crictl`的设计目的是理顺 Docker CLI 的功能，为用户提供更好的过渡体验，但是和 Docker CLI 又不尽相同。下面讲讲两者之间的一些重要区别。

### 适用范围：crictl 是一个排错工具\(/etc/crictl.yaml\) {#适用范围-crictl-是一个排错工具}

`crictl`的设计目的是排错，并非 Docker 或者 kubectl 的替代品。Docker 的 CLI 提供了大量的命令，使之成为重要的开发工具，但是在 Kubernetes 节点排错方面，就不尽人意了。有些 Docker 命令在 Kubernetes 上没什么用，例如`docker network`和`docker build`；有些甚至会损害系统，比如说`docker rename`，`crictl`提供了刚好够用的命令来进行节点方面的除错工作，对于生产节点来说，明显会有更好的安全性。

### Kubernetes 特性 {#kubernetes-特性}

`crictl`提供了一个对 Kubernetes 来说更加友好的容器视角。Docker CLI 并不了解 Kubernetes 的概念，例如`pod`和[`namespace`](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)，所以他无法提供容器和 Pod 的清晰视图。一个例子就是`docker ps`的混乱输出：过长的 Docker 容器名称、Pause 容器和应用容器混杂在一起：

![](/assets/dockerimport.png)[Pause 容器](https://www.ianlewis.org/en/almighty-pause-container)是一个 Pod 的实现手段，每个 Pod 都会有一个 Pause 容器，所以列出 Pod 中包含的容器的时候，没必要把 Pause 容器显示出来。

而`crictl`是为 Kubernetes 设计的，他有不同的一组命令来和 Pod 以及容器进行交互。例如`crictl pods`会列出 Pod 信息，而`crictl ps`只会列出应用容器的信息。所有的信息都以表格形式进行展示。

![](/assets/ctrictlimport.png)关于`crictl`在 containerd 方面的细节，可以参看：

* [文档](https://github.com/containerd/cri/blob/master/docs/crictl.md)
* [演示视频](https://asciinema.org/a/179047)

## Docker 怎么办？ {#docker-怎么办}

“切换到 Containerd 是不是说我不能再用 Docker Engine 了？”我们经常听到这个问题，简单的答案就是：NO。

Docker Engine 是在 Containerd 之上构建的。下个版本的[Docker CE](https://www.docker.com/community-edition)就会使用 Containerd 1.1。当然，也就会有内置的缺省激活的 CRI 插件。这样一来，用户可以选择继续使用 Docker Engine 来做一些 Docker 的事情，也可以配置 Kubernetes 来使用其中的 Containerd，同时 Containerd 还会同时给同一节点上的 Docker Engine 提供支撑。下面的架构图就描述了 Docker Engine 和 Kubelet 共用 Containerd 的情况：

![](/assets/asbaimport.png)

既然 Containerd 同时能够给 Kubelet 和 Docker Engine 提供支持，选择了使用 Containerd 集成的用户，得到的不仅仅是新的 Kubernetes 特性、性能和稳定性的增强，他们还会得到保留 Docker Engine 以便用于其他用例的选择。

Containerd 的[命名空间](https://github.com/containerd/containerd/blob/master/docs/namespaces.md)机制，让 Kubelet 和 Docker Engine 之间无法互相访问对方的容器和镜像。这样就保证了他们无法互相影响，这样的后果：

*   用 docker ps 命令无法看到 Kubernetes 创建的容器；而应该使用 crictl ps。反之亦然，用 crictl ps 也是无法看到 Docker CLI 创建的容器。crictl create 以及 crictl runp 命令只用于出错。不推荐在生产节点上手动使用 crictl 启动 Pod 或者容器。
*   docker images 不会看到 Kubernetes 拉回的镜像。同样需要使用 crictl images 命令。反过来用 docker pull、docker load 或者 docker build 生成的镜像，Kubernetes 也是无法看到的。可以使用 crictl pull 命令来替代，可以使用 \[ctr\]\([https://github.com/containerd/containerd/blob/master/docs/man/ctr.1.md](https://github.com/containerd/containerd/blob/master/docs/man/ctr.1.md)\) cri load 来载入镜像。

## 总结 {#总结}

* Containerd 1.1 天然支持 CRI，可以直接给 Kubernetes 使用。
* Containerd 1.1 满足生产要求。
* Containerd 1.1 在 Pod 启动延迟和系统资源占用方面具有良好的性能表现。
* `crictl`是用于和 Containerd 1.1 以及其他 cri 兼容的容器运行时进行操作和节点除错的 CLI 工具。
* 下一个 Docker CE 版本会包含 Containerd 1.1。用户有选择继续使用 Docker 来满足 Kubernetes 之外的容器需求，同时让 Kubernetes 使用来自 Docker 的同样的底层容器运行时。





