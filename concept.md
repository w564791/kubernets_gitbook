### Node

Kubernetes集群中的计算能力由Node提供，最初Node称为服务节点Minion，后来改名为Node。Kubernetes集群中的Node也就等同于Mesos集群中的Slave节点，是所有Pod运行所在的工作主机，可以是物理机也可以是虚拟机。不论是物理机还是虚拟机，工作主机的统一特征是上面要运行kubelet管理节点上运行的容器。

### POD

是kubernetes最基本的操作单元,一个Pod可能包含多个容器,相同Pod内的容器可以通过localhost进行通信,但是端口不能相同,Pod在Node上被创建,启动或销毁,Pod不能跨Node,Pod容器和Node之间的关系如下图:

![](/assets/impor2t.png)

一个Pod种的应用容器共享同一组资源:

* PID命名空间:Pod种的不用应用程序可以看到其他应用程序的进程ID
* 网络命名空间:Pod种的多个容器能够访问同一个IP和端口范围
* IPC命名空间:Pod种的多个容器能使用SystemV IPC或POSIX消息队列进行通信
* UTS命名空间:Pod种的多个容器共享一个主机名
* Volumes\(共享存储卷\):Pod种的各个容器可以访问在Pod级别定义的Volumes

Pod状态:

* Pending:Pod定义正确,提交到Master,但是所需的容器镜像未完全创建
* Running:Pod已经被村配到某个Node上,其包含的容器镜像已经创建完成
* Terminied:Pod正在终止
* Failed\(err &.\):Pod种所有容器都结束了,但至少一个容器是以失败状态结束的.
* 其它\(参考文献比较旧,后面补充\)

每一个副本都会有与之对应的docker pod 容器运行,其作用:\(同一个pod内的容器之间可以通过localhost相互通信\)

### **Service**:

Kubernetes虽然会对每一个Pod分配一个单独的IP地址,但是这个IP地址会随着Pod的销毁而消失,如果有一组Pod组成一个集群来提供服务,那么如何来访问他呢,Service就是用来解决这个问题的.

Service可以跨Node运行;Node,Pod,Service,Container关系如下图:

![](/assets/import3.png)

正常启动后,系统会根据Service的定义创建出于Pod对应的Endpoint对象,以建立起Service与后端Pod的对应关系,随着Pod的创建,销毁,Endpoint对象也将被更新,Endpoint对象主要由Pod的IP地址和容器需要监听的端口号组成,通过kubectl get endpoint可以查看.Service定义的IP\(下文简称SVIP\)只能在内部\(即Pod之间,Service之间\)访问;如果要从外部访问,我们只需要将这个Service的端口开放到出去即可\(每个节点都会启动相应的端口\),Kubernetes目前支持3种对外服务的Service的type定义:NodePort,LoadBalancer和ingress

#### **ingress**

推荐的方式,通过 Ingress 用户可以实现使用 nginx 等开源的反向代理负载均衡器实现对外暴露服务.

使用 Ingress 时一般会有三个组件:

* 反向代理负载均衡器
* Ingress Controller
* Ingress

###### 反向代理负载均衡器

反向代理负载均衡器很简单，说白了就是 nginx、apache 什么的；在集群中反向代理负载均衡器可以自由部署，可以使用 Replication Controller、Deployment、DaemonSet 等等，不过个人喜欢以 DaemonSet 的方式部署，感觉比较方便

###### Ingress Controller

Ingress Controller 实质上可以理解为是个监视器，Ingress Controller 通过不断地跟 kubernetes API 打交道，实时的感知后端 service、pod 等变化，比如新增和减少 pod，service 增加与减少等；当得到这些变化信息后，Ingress Controller 再结合下文的 Ingress 生成配置，然后更新反向代理负载均衡器，并刷新其配置，达到服务发现的作用

###### Ingress

Ingress 简单理解就是个规则定义；比如说某个域名对应某个 service，即当某个域名的请求进来时转发给某个 service;这个规则将与 Ingress Controller 结合，然后 Ingress Controller 将其动态写入到负载均衡器配置中，从而实现整体的服务发现和负载均衡

如图:

![](/assets/import22.png)

从上图中可以很清晰的看到，实际上请求进来还是被负载均衡器拦截，比如 nginx，然后 Ingress Controller 通过跟 Ingress 交互得知某个域名对应哪个 service，再通过跟 kubernetes API 交互得知 service 地址等信息；综合以后生成配置文件实时写入负载均衡器，然后负载均衡器 reload 该规则便可实现服务发现，即动态映射

了解了以上内容以后，这也就很好的说明了我为什么喜欢把负载均衡器部署为 Daemon Set；因为无论如何请求首先是被负载均衡器拦截的，所以在每个 node 上都部署一下，同时 hostport 方式监听 80 端口；那么就解决了其他方式部署不确定 负载均衡器在哪的问题，同时访问每个 node 的 80 都能正确解析请求；如果前端再 放个 nginx 就又实现了一层负载均衡

### **NodePort**:

在定义Service时指定spec.type=NodePort,并指定spec.ports.nodePort值,系统会在集群种的每个Node上打开一个主机上的真实端口号,这样能放问Node的客户端都能通过任意一个Node来访问这个端口,进而访问内部的Service.

### **LoadBalancer**:

如果云服务商支持外接负载均衡器,则可以通过spec.type=LoadBalancer定义Service,同时需要指定负载均衡器的IP,同事还需要指定Service的NodePort和clusterIP.

### **Replication Controller\(RC\)**:

RC\(简写\)用于定义Pod的副本数量,在Master内,Controller Manager进程通过RC的定义来完成Pod的创建,监控,销毁等操作\(Pod也可以单独启动\); Kubernetes能确保在任意时刻都能运行用户指定的”副本”\(Replica\)数量,如果有过多的Pod副本在运行.系统就会停掉一些;如果Pod数量少于指定数量,系统就会再启动一些Pod

### **Label**:

Label是Kubernetes系统中的一个核心概念;Label以key/value的键值对的形式附加到各种对象上,如Pod,Service,RC,Node等,Label定义了这些对象的可识别属性,用来对它们进行管理和选择,Label可以在创建对象时附加到对象上,也可以在对象创建后通过API管理,在为对象定义好Label后,其他对象可以使用Label Selector来定义其作用对象.\(详细参考Kubernetes权威指南第1版第21页\)

### **Volume**:

Volume是Pod种能够被多个容器访问的共享目录,Kubernetes种的Volume与Pod的生命周期相同,与容器的生命周期不想关,当容器终止会重启时,Volume种的数据不会丢失.

### **Namespace**:

Namespace是Kubernetes系统中一个很重要的概念,通过系统内部的对象分配到不容的Namespace中,形成逻辑上分组不通的项目,小组或用户组,便于不同的分组在共享使用整个集群资源的同时还能被分别管理

集群中的一些简写:

* componentstatuses \(aka 'cs'\)
* configmaps \(aka 'cm'\)
* daemonsets \(aka 'ds'\)
* deployments \(aka 'deploy'\)
* endpoints \(aka 'ep'\)
* events \(aka 'ev'\)
* horizontalpodautoscalers \(aka 'hpa'\)
* ingresses \(aka 'ing'\)
* limitranges \(aka 'limits'\)
* namespaces \(aka 'ns'\)
* nodes \(aka 'no'\)
* persistentvolumeclaims \(aka 'pvc'\)
* persistentvolumes \(aka 'pv'\)
* pods \(aka 'po'\)
* podsecuritypolicies \(aka 'psp'\)
* replicasets \(aka 'rs'\)
* replicationcontrollers \(aka 'rc'\)
* resourcequotas \(aka 'quota'\)
* serviceaccounts \(aka 'sa'\)
* services \(aka 'svc'\)

比如 kubectl get nodes 可以简写为kubectl get no

### **Endpoint**:

保留:暂时不知道怎么解释

## 新的概念:

#### 副本集（Replica Set，RS）

RS是新一代RC，提供同样的高可用能力，区别主要在于RS后来居上，能支持更多种类的匹配模式。副本集对象一般不单独使用，而是作为Deployment的理想状态参数使用。

### 部署\(Deployment\)

部署表示用户对Kubernetes集群的一次更新操作。部署是一个比RS应用模式更广的API对象，可以是创建一个新的服务，更新一个新的服务，也可以是滚动升级一个服务。滚动升级一个服务，实际是创建一个新的RS，然后逐渐将新RS中副本数增加到理想状态，将旧RS中的副本数减小到0的复合操作；这样一个复合操作用一个RS是不太好描述的，所以用一个更通用的Deployment来描述。以Kubernetes的发展方向，未来对所有长期伺服型的的业务的管理，都会通过Deployment来管理。

### 任务（Job）

Job是Kubernetes用来控制批处理型任务的API对象。批处理业务与长期伺服业务的主要区别是批处理业务的运行有头有尾，而长期伺服业务在用户不停止的情况下永远运行。Job管理的Pod根据用户的设置把任务成功完成就自动退出了。成功完成的标志根据不同的spec.completions策略而不同：单Pod型任务有一个Pod成功就标志完成；定数成功型任务保证有N个任务全部成功；工作队列型任务根据应用确认的全局成功而标志成功。

### 后台支撑服务集（DaemonSet）

长期伺服型和批处理型服务的核心在业务应用，可能有些节点运行多个同类业务的Pod，有些节点上又没有这类Pod运行；而后台支撑型服务的核心关注点在Kubernetes集群中的节点（物理机或虚拟机），要保证每个节点上都有一个此类Pod运行。节点可能是所有集群节点也可能是通过nodeSelector选定的一些特定节点。典型的后台支撑型服务包括，存储，日志和监控等在每个节点上支持Kubernetes集群运行的服务。

### 有状态服务集（PetSet）

Kubernetes在1.3版本里发布了Alpha版的PetSet功能。在云原生应用的体系里，有下面两组近义词；第一组是无状态（stateless）、牲畜（cattle）、无名（nameless）、可丢弃（disposable）；第二组是有状态（stateful）、宠物（pet）、有名（having name）、不可丢弃（non-disposable）。RC和RS主要是控制提供无状态服务的，其所控制的Pod的名字是随机设置的，一个Pod出故障了就被丢弃掉，在另一个地方重启一个新的Pod，名字变了、名字和启动在哪儿都不重要，重要的只是Pod总数；而PetSet是用来控制有状态服务，PetSet中的每个Pod的名字都是事先确定的，不能更改。PetSet中Pod的名字的作用，并不是《千与千寻》的人性原因，而是关联与该Pod对应的状态。

对于RC和RS中的Pod，一般不挂载存储或者挂载共享存储，保存的是所有Pod共享的状态，Pod像牲畜一样没有分别（这似乎也确实意味着失去了人性特征）；对于PetSet中的Pod，每个Pod挂载自己独立的存储，如果一个Pod出现故障，从其他节点启动一个同样名字的Pod，要挂在上原来Pod的存储继续以它的状态提供服务。

适合于PetSet的业务包括数据库服务MySQL和PostgreSQL，集群化管理服务Zookeeper、etcd等有状态服务。PetSet的另一种典型应用场景是作为一种比普通容器更稳定可靠的模拟虚拟机的机制。传统的虚拟机正是一种有状态的宠物，运维人员需要不断地维护它，容器刚开始流行时，我们用容器来模拟虚拟机使用，所有状态都保存在容器里，而这已被证明是非常不安全、不可靠的。使用PetSet，Pod仍然可以通过漂移到不同节点提供高可用，而存储也可以通过外挂的存储来提供高可靠性，PetSet做的只是将确定的Pod与确定的存储关联起来保证状态的连续性。PetSet还只在Alpha阶段，后面的设计如何演变，我们还要继续观察。

### 集群联邦（Federation）

Kubernetes在1.3版本里发布了beta版的Federation功能。在云计算环境中，服务的作用距离范围从近到远一般可以有：同主机（Host，Node）、跨主机同可用区（Available Zone）、跨可用区同地区（Region）、跨地区同服务商（Cloud Service Provider）、跨云平台。Kubernetes的设计定位是单一集群在同一个地域内，因为同一个地区的网络性能才能满足Kubernetes的调度和计算存储连接要求。而联合集群服务就是为提供跨Region跨服务商Kubernetes集群服务而设计的。

每个Kubernetes Federation有自己的分布式存储、API Server和Controller Manager。用户可以通过Federation的API Server注册该Federation的成员Kubernetes Cluster。当用户通过Federation的API Server创建、更改API对象时，Federation API Server会在自己所有注册的子Kubernetes Cluster都创建一份对应的API对象。在提供业务请求服务时，Kubernetes Federation会先在自己的各个子Cluster之间做负载均衡，而对于发送到某个具体Kubernetes Cluster的业务请求，会依照这个Kubernetes Cluster独立提供服务时一样的调度模式去做Kubernetes Cluster内部的负载均衡。而Cluster之间的负载均衡是通过域名服务的负载均衡来实现的。

所有的设计都尽量不影响Kubernetes Cluster现有的工作机制，这样对于每个子Kubernetes集群来说，并不需要更外层的有一个Kubernetes Federation，也就是意味着所有现有的Kubernetes代码和机制不需要因为Federation功能有任何变化。

### 持久存储卷（Persistent Volume，PV）和持久存储卷声明（Persistent Volume Claim，PVC）

PV和PVC使得Kubernetes集群具备了存储的逻辑抽象能力，使得在配置Pod的逻辑里可以忽略对实际后台存储技术的配置，而把这项配置的工作交给PV的配置者，即集群的管理者。存储的PV和PVC的这种关系，跟计算的Node和Pod的关系是非常类似的；PV和Node是资源的提供者，根据集群的基础设施变化而变化，由Kubernetes集群管理员配置；而PVC和Pod是资源的使用者，根据业务服务的需求变化而变化，有Kubernetes集群的使用者即服务的管理员来配置。

### 密钥对象（Secret）

Secret是用来保存和传递密码、密钥、认证凭证这些敏感信息的对象。使用Secret的好处是可以避免把敏感信息明文写在配置文件里。在Kubernetes集群中配置和使用服务不可避免的要用到各种敏感信息实现登录、认证等功能，例如访问AWS存储的用户名密码。为了避免将类似的敏感信息明文写在所有需要使用的配置文件中，可以将这些信息存入一个Secret对象，而在配置文件中通过Secret对象引用这些敏感信息。这种方式的好处包括：意图明确，避免重复，减少暴漏机会。

### 用户帐户（User Account）和服务帐户（Service Account）

顾名思义，用户帐户为人提供账户标识，而服务账户为计算机进程和Kubernetes集群中运行的Pod提供账户标识。用户帐户和服务帐户的一个区别是作用范围；用户帐户对应的是人的身份，人的身份与服务的namespace无关，所以用户账户是跨namespace的；而服务帐户对应的是一个运行中程序的身份，与特定namespace是相关的。

### RBAC访问授权

Kubernetes在1.3版本中发布了alpha版的基于角色的访问控制（Role-based Access Control，RBAC）的授权模式。相对于基于属性的访问控制（Attribute-based Access Control，ABAC），RBAC主要是引入了角色（Role）和角色绑定（RoleBinding）的抽象概念。在ABAC中，Kubernetes集群中的访问策略只能跟用户直接关联；而在RBAC中，访问策略可以跟某个角色关联，具体的用户在跟一个或多个角色相关联。显然，RBAC像其他新功能一样，每次引入新功能，都会引入新的API对象，从而引入新的概念抽象，而这一新的概念抽象一定会使集群服务管理和使用更容易扩展和重用。





参考文献:

\[1\]&lt;&lt;Kubernetes权威指南&gt;&gt;第一版

\[2\] [http://www.infoq.com/cn/articles/kubernetes-and-cloud-native-applications-part01](http://www.infoq.com/cn/articles/kubernetes-and-cloud-native-applications-part01)

