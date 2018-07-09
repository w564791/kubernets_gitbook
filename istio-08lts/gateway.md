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



