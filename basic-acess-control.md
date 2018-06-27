# 基本访问控制 {#title}

开始之前

* 需要istio被正确安装
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例

将来自jason用户的请求引导至V2版本,将其他用户的请求引导到V3版本



```
istioctl create -f samples/bookinfo/routing/route-rule-all-v1.yaml
cat <<EOF | istioctl create -f -
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



```

```

```

```



