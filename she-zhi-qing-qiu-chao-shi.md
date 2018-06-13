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

刷新Bookinfo网页,您现在应该看到它在仍然是2秒返回，评论返回_Sorry, product reviews are currently unavailable for this book._

\(按理说这里超时时间设置为1秒,页面应该在1秒内返回,不知道为什么这里等了2秒,难道还有重试1次?\)

## 了解发生了什么 {#understanding-what-happened}

在此任务中，您使用Istio将调用`reviews`微服务的请求超时设置为1秒（而不是默认的15秒）。由于该`reviews`服务随后`ratings`在处理请求时调用该服务，因此您使用Istio在呼叫中注入了2秒的延迟时间`ratings`，以便您可以使`reviews`服务花费超过1秒的时间来完成，因此您可以看到超时运行。

您发现Bookinfo产品页面（调用`reviews`服务来填充页面）而不显示评论，显示消息：_Sorry, product reviews are currently unavailable for this book_。这是它从reviews服务收到超时错误的结果。

