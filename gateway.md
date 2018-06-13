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

只能同时存在一个gateway,否则会报错:

```
[warning][config] bazel-out/k8-opt/bin/external/envoy/source/common/config/_virtual_includes/grpc_mux_subscription_lib/common/config/grpc_mux_subscription_impl.h:70] gRPC config for type.googleapis.com/envoy.api.v2.Listener rejected: Error adding/updating listener 0.0.0.0_80: error adding listener '0.0.0.0:80': multiple filter chains with the same matching rules are defined
```



