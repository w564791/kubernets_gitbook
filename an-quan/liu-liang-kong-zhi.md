## 在开始之前

* 部署istio\(本例使用了mtls,若未使用,若未使用,下例第一条使用[samples/bookinfo/routing/route-rule-all-v1.yaml的内容](https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/route-rule-all-v1.yaml)\)
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序
* 将所有流量导向v3,jason用户流量导向v2

```
$   istioctl create -f samples/bookinfo/routing/route-rule-all-v1-mtls.yaml
```

```
  # cat <<EOF| istioctl replace -f -
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
          subset: v3
EOF
```

确认当前非jason用户登录时可以看到红星评价,jason用户登录时是黑星评价

## 限制流量



