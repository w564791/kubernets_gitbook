### 开始之前

* 部署istio服务

* [部署bookinfo示例](https://istio.io/docs/guides/bookinfo/)

将所有的流量导向v3,Jason用户的流量导向v2

```
# istioctl create -f samples/bookinfo/routing/route-rule-all-v1.yaml
# cat <<EOF | istioctl create -f -
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



