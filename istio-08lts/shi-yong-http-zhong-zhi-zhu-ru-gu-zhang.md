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

