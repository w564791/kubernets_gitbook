## 在开始之前

* 部署istio
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序
* 将所有流量导向v3,jason用户流量导向v2

```
$   istioctl create -f samples/bookinfo/routing/route-rule-all-v1.yaml

```

```
  # cat <<EOF| istioctl create -f -
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



