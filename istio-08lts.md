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
---
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



