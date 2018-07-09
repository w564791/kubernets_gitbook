这个例子主要展示了istio如何配置收集trace spans,完成该任务时,你会知道你的程序如何参与追踪,无论你使用哪种语言/框架/平台哎构建应用

## 在开始之前

* 正确安装istio
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序

### 访问dashboard

使用nodePort暴露jaeger的端口

```
# kubectl get  svc -n istio-system tracing -o jsonpath={.spec.ports[0].nodePort}
16686
```

使用istio-ingress暴露jaeger服务

```
# istioctl get  virtualservice jaeger -o yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  creationTimestamp: null
  name: jaeger
  namespace: default
  resourceVersion: "1150555"
spec:
  gateways:
  - bookinfo-gateway
  hosts:
  - jaeger.example.com
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: tracing.istio-system.svc.cluster.local
        port:
          number: 16686
---
```

### 使用bookinfo示例生成追踪

请求bookinfo的productpage一次或者多次,可以在jaeger-dashboard看到如下内容:

![](/assets/jaeger-dashboard.png)点击搜索结果可以查看详细信息:

![](/assets/jaeger-result.png)红色感叹号表示有错误,点击可以查看更详细的信息

![](/assets/jaeger-err.png)可以看到此时的http.status\_code=0,因为在本示例之前,做过请求速率限制.该功能能更迅速定位问题,更清晰的了解各服务之间的时间消耗情况.

## 了解发生了什么 {#understanding-what-happened}

尽管istio代理能够自动发送spans,同时他们也需要一些提示来将这些内容联系在一起,所以,当proxies发送span信息应用时,程序需要传递适当的http头,span可以正确的关联到单个trace里.

因此,应用程序需要收集传入请求中的以下header,并传到任务传出的request

```
x-request-id
x-b3-traceid
x-b3-spanid
x-b3-parentspanid
x-b3-sampled
x-b3-flags
x-ot-span-context
```



