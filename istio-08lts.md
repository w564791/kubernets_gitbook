# Istio v1aplha3 routing API



Up until now, Istio has provided a simple API for traffic management using four configuration resources: RouteRule, DestinationPolicy, EgressRule, and \(Kubernetes\) Ingress. With this API, users have been able to easily manage the flow of traffic in an Istio service mesh. The API has allowed users to route requests to specific versions of services, inject delays and failures for resilience testing, add timeouts and circuit breakers, and more, all without changing the application code itself.

到目前为止，Istio提供了一个简单的API来进行流量管理，该API包括了四种资源：RouteRule、DestinationPolicy、EgressRule和Ingress（直接使用了Kubernets的Ingress资源）。借助此API，用户可以轻松管理Istio服务网格中的流量。该API允许用户将请求路由到特定版本的服务，为弹性测试注入延迟和失败，添加超时和断路器等等，所有这些功能都不必更改应用程序本身的代码。

While this functionality has proven to be a very compelling part of Istio, user feedback has also shown that this API does have some shortcomings, specifically when using it to manage very large applications containing thousands of services, and when working with protocols other than HTTP. Furthermore, the use of Kubernetes Ingress resources to configure external traffic has proven to be woefully insufficient for our needs.

虽然目前API的功能已被证明是Istio非常引人注目的一部分，但也有一些用户反馈该API确实有一些缺点，尤其是在使用它来管理包含数千个服务的大型应用，以及使用HTTP以外的协议时。 此外，使用Kubernetes Ingress资源来配置外部流量的方式已被证明不能满足需求。

To address these, and other concerns, a new traffic management API, a.k.a. v1alpha3, is being introduced, which will completely replace the previous API going forward. Although the v1alpha3 model is fundamentally the same, it is not backward compatible and will require manual conversion from the old API. A conversion tool is included in the next few releases of Istio to help with the transition.

为了解决上述缺陷和其他的一些问题，Istio引入了新的流量管理API v1alpha3，新版本的API将完全取代之前的API。 尽管v1alpha3和之前的模型在本质上是基本相同的，但旧版API并不向后兼容，基于旧API的模型需要进行手动转换。Istio的后续版本中会提供一个新旧模型的转换工具。

To justify this disruption, the v1alpha3 API has gone through a long and painstaking community review process that has hopefully resulted in a greatly improved API that will stand the test of time. In this article, we will introduce the new configuration model and attempt to explain some of the motivation and design principles that influenced it.



为了证明该非兼容性升级的必要性，v1alpha3 API经历了漫长而艰苦的社区评估过程，以希望新的API能够大幅改进，并经得起时间的考验。在本文中，我们将介绍新的配置模型，并试图解释其后面的一些动机和设计原则。

##  {#design-principles}



