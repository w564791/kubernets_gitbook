# 

# Istio v1aplha3 routing API介绍

FROM  [_https://servicemesher.github.io/blog/introducing-the-istio-v1alpha3-routing-api/_](https://servicemesher.github.io/blog/introducing-the-istio-v1alpha3-routing-api/)

到目前为止，Istio提供了一个简单的API来进行流量管理，该API包括了四种资源：RouteRule、DestinationPolicy、EgressRule和Ingress（直接使用了Kubernets的Ingress资源）。借助此API，用户可以轻松管理Istio服务网格中的流量。该API允许用户将请求路由到特定版本的服务，为弹性测试注入延迟和失败，添加超时和断路器等等，所有这些功能都不必更改应用程序本身的代码。

虽然目前API的功能已被证明是Istio非常引人注目的一部分，但也有一些用户反馈该API确实有一些缺点，尤其是在使用它来管理包含数千个服务的大型应用，以及使用HTTP以外的协议时。 此外，使用Kubernetes Ingress资源来配置外部流量的方式已被证明不能满足需求。

为了解决上述缺陷和其他的一些问题，Istio引入了新的流量管理API v1alpha3，**新版本的API将完全取代之前的API**。 尽管v1alpha3和之前的模型在本质上是基本相同的，但旧版API并不向后兼容，基于旧API的模型需要进行手动转换。Istio的后续版本中会提供一个新旧模型的转换工具。

为了证明该非兼容性升级的必要性，v1alpha3 API经历了漫长而艰苦的社区评估过程，以希望新的API能够大幅改进，并经得起时间的考验。在本文中，我们将介绍新的配置模型，并试图解释其后面的一些动机和设计原则。

## 设计原则 {#设计原则}

路由模型的重构过程中遵循了一些关键的设计原则：

* 除支持声明式（意图）配置外，也支持显式指定模型依赖的基础设施。例如，除了配置入口网关（的功能特性）之外，负责实现入口网关功能的组件（Controller）也可以在模型指定。
* 编写模型时应该“生产者导向”和“以Host为中心”，而不是通过组合多个规则来编写模型。 例如，所有与特定Host关联的规则被配置在一起，而不是单独配置。
* 将路由与路由后行为清晰分开。

## v1alpha3中的配置资源 {#v1alpha3中的配置资源}

在一个典型的网格中，通常有一个或多个用于终止外部TLS链接，将流量引入网格的负载均衡器（我们称之为gateway）。 然后流量通过sidecar网关（sidecar gateway）流经内部服务。应用程序使用外部服务的情况也很常见（例如访问Google Maps API），一些情况下，这些外部服务可能被直接调用；但在某些部署中，网格中所有访问外部服务的流量可能被要求强制通过专用的出口网关（Egress gateway）。 下图描绘了网关在网格中的使用情况。

![](/assets/importasas.png)

考虑到上述因素，`v1alpha3`引入了以下这些新的配置资源来控制进入网格、网格内部和离开网格的流量路由。

1. `Gateway`
2. `VirtualService`
3. `DestinationRule`
4. `ServiceEntry`

`VirtualService`、`DestinationRule`和`ServiceEntry`分别替换了原API中的`RouteRule`、`DestinationPolicy`和`EgressRule`。`Gateway`是一个独立于平台的抽象，用于对流入专用中间设备的流量进行建模。

下图描述了跨多个配置资源的控制流程。

![](/assets/import1231.png)

### base: {#gateway}

1. [istio 0.8已在集群中安装安装](/istio-08lts/istio-08bu-shu.md)
2. [bookinfo示例已部署](/istio-08lts/bookinfoshi-li-bu-shu.md)

### Gateway {#gateway}

[Gateway](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#Gateway)用于为HTTP/TCP流量配置负载均衡器，并不管该负载均衡器将在哪里运行。网格中可以存在任意数量的Gateway，并且多个不同的Gateway实现可以共存。实际上，通过在配置中指定一组工作负载（Pod）标签，可以将Gateway配置绑定到特定的工作负载，从而允许用户通过编写简单的Gateway Controller来重用现成的网络设备。

对于入口流量管理，您可能会问：为什么不直接使用Kubernetes Ingress API？原因是Ingress API无法表达Istio的路由需求。Ingress试图在不同的HTTP代理之间取一个公共的交集，因此只能支持最基本的HTTP路由，最终导致需要将代理的其他高级功能放入到注解（annotation）中，而注解的方式在多个代理之间是不兼容的，无法移植。

Istio`Gateway`通过将L4-L6配置与L7配置分离的方式克服了`Ingress`的这些缺点。`Gateway`只用于配置L4-L6功能（例如，对外公开的端口、TLS配置），所有主流的L7代理均以统一的方式实现了这些功能。 然后，通过在`Gateway`上绑定`VirtualService`的方式，可以使用标准的Istio规则来控制进入`Gateway`的HTTP和TCP流量。

```
# cat bookinfo-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

Gateway可以用于建模边缘代理或纯粹的内部代理，如第一张图所示。无论在哪个位置，所有网关都可以用相同的方式进行配置和控制。

### VirtualService {#virtualservice}

要为进入上面的Gateway的流量配置相应的路由，必须为同一个host定义一个VirtualService，并使用配置中的gateways字段绑定到前面定义的Gateway 上：

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
spec:
  hosts:
  - "*"
  gateways:
  - bookinfo-gateway  #绑定gateway ,官网下载的例子(绑定了不存在的bookinfo和mesh GateWay)也能暴露服务,不知道是不是这个选项无效
  http:
  - match:
    - uri:
        exact: /productpage
    - uri:
        exact: /login
    - uri:
        exact: /logout
    - uri:
        prefix: /api/v1/products
    route:
    - destination:
        host: productpage
        port:
          number: 9080
```

用一种叫做“Virtual services”的东西代替路由规则可能看起来有点奇怪，但对于它配置的内容而言，这事实上是一个更好的名称，特别是在重新设计API以解决先前模型的可扩展性问题之后。

实际上，发生的变化是：在之前的模型中，需要用一组相互独立的配置规则来为特定的目的服务设置路由规则，并通过precedence字段来控制这些规则的顺序；在新的API中，则直接对（虚拟）服务进行配置，该虚拟服务的所有规则以一个有序列表的方式配置在对应的VirtualService资源中。

v1alph3示例

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - match:
    - headers:
        cookie:
          regex: "^(.*?;)?(user=jason)(;.*)?$"
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

将默认流量导入version: v1标签的容器,将cookie包含user=jason的用户流量导入version: v2标签的容器

实际上在`VirtualService`中hosts部分设置只是虚拟的目的地，因此不一定是已在网格中注册的服务。这允许用户为在网格内没有可路由条目的虚拟主机的流量进行建模。通过将`VirtualService`绑定到同一Host的`Gateway`配置（如前一节所述 ），可向网格外部暴露这些Host。

除了这个重大的重构之外，`VirtualService`还包括其他一些重要的改变：

1. 可以在`VirtualService`配置中表示多个匹配条件，从而减少对冗余的规则设置。
2. 每个服务版本都有一个名称（称为服务子集）。属于某个子集的一组Pod/VM在`DestinationRule`中定义，具体定义参见下节。
3. 通过使用带通配符前缀的DNS来指定`VirtualService`的host，可以创建单个规则以作用于所有匹配的服务。例如，在Kubernetes中，在`VirtualService`中使用`*.foo.svc.cluster.local`作为host,可以对`foo`命名空间中的所有服务应用相同的重写规则。

### DestinationRule {#destinationrule}

[DestinationRule](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#DestinationRule)用于配置在将流量转发到服务时应用的策略集。这些策略应由服务提供者撰写，用于描述断路器、负载均衡、TLS设置等。

除了下述改变外，`DestinationRule`与其前身`DestinationPolicy`大致相同。

1. [DestinationRule](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#DestinationRule)的`host`可以包含通配符前缀，以允许单个规则应用于多个服务。

2. `DestinationRule`定义了目的host的子集`subsets`（例如：命名版本）。 这些subset用`VirtualService`的路由规则设置中，可以将流量导向服务的某些特定版本。通过这种方式为版本命名后，可以在不同的虚拟服务中明确地引用这些命名版本的subset，简化Istio代理发出的统计数据，并可以将subsets编码到SNI头中。

为reviews服务配置策略和subsets的`DestinationRule`可能如下所示：

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
  - name: v3
    labels:
      version: v3
```

在单个`DestinationRule`中指定多个策略（例如上面实例中的缺省策略和v2版本特定的策略）。

### 使用HTTP延迟注入故障

```
# cat route-rule-ratings-test-delay.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        cookie:
          regex: "^(.*?;)?(user=jason)(;.*)?$"
    fault:
      delay:
        percent: 100
        fixedDelay: 7s
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1


# istioctl  replace -f route-rule-ratings-test-delay.yaml
Updated config virtual-service/default/ratings to revision 617014
```

以用户“jason”身份登录。 如果应用程序的首页设置为正确处理延迟，我们预计它将在大约7秒内加载。 要查看网页响应时间，请打开IE，Chrome或Firefox（通常为组合键Ctrl + Shift + I或Alt + Cmd + I），选项卡网络中的开发人员工具菜单，然后重新加载productpage网页。 您会看到网页在大约6秒钟内加载完毕。 评论部分将显示_Sorry, product reviews are currently unavailable for this book_

### 其中发生了什么

整个评论服务失败的原因是因为我们的Bookinfo应用程序有一个错误。 产品页面和评论服务之间的超时时间比评论和评分服务之间的超时（硬编码连接超时时间为10秒）要少（总共3s + 1次重试= 6s）。 典型的企业应用程序可能出现这些类型的错误，其中不同的团队独立开发不同的微服务。 Istio的故障注入规则可以帮助您识别这些异常情况，而不会影响最终用户。

### 使用HTTP终止注入故障

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - match:
    - headers:
        cookie:
          regex: "^(.*?;)?(user=jason)(;.*)?$"
    fault:
      abort:
        percent: 100
        httpStatus: 500
    route:
    - destination:
        host: ratings
        subset: v1
  - route:
    - destination:
        host: ratings
        subset: v1
```

以用户“jason”登录。 如果规则成功传播到所有窗格，您应该立即看到页面加载了“_Ratings service is currently unavailable_”消息。 从用户“jason”注销，您应该可以在产品页面上看到带评级星的评论。

## 设置请求超时 {#request-timeouts}

可以使用路由规则的http requests timeout字段指定http请求的超时值。默认情况下，超时时间为15秒，但在此任务中，我们将覆盖reviews服务超时时间为1秒。然而，为了看到它的效果，我们还会在ratings服务调用中引入一个人为的2秒延迟

1.将请求路由到`reviews`服务的v2 ，即调用该ratings服务的版本

```
cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
EOF
```

2.添加2秒的延迟呼叫`ratings`服务：

```
cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percent: 100
        fixedDelay: 2s
    route:
    - destination:
        host: ratings
        subset: v1
EOF
```

3.在浏览器中打开Bookinfo URL（http：// $ GATEWAY\_URL / productpage）  
您应该看到Bookinfo应用程序正常工作（显示评分星），但每当刷新页面时都会有2秒的延迟。

4.现在为reviews服务呼叫添加1秒的请求超时

```
cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v2
    timeout: 1s
EOF
```

5. 刷新Bookinfo网页,您现在应该看到它在仍然是2秒返回，但评论返回_Sorry, product reviews are currently unavailable for this book._



