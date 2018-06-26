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

### 使用拒绝控制

参考bookinfo示例,ratings服务由多个reviews服务访问,我们希望切断来自v3对ratings的请求

当前状态:

* 使用jason用户登录,可以看到黑星评级,表明ratings正在被v2版本的reviews服务访问
* 注销jason用户,可以看到红星评级,表明ratings正在被v3版本的reviews服务访问

创建明确对reviews服务v3版本的拒绝请求

```
cat <<EOF | istioctl create -f -
apiVersion: "config.istio.io/v1alpha2"
kind: denier
metadata:
  name: denyreviewsv3handler
spec:
  status:
    code: 7
    message: Not allowed
---
apiVersion: "config.istio.io/v1alpha2"
kind: checknothing
metadata:
  name: denyreviewsv3request
spec:
---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: denyreviewsv3
spec:
  match: destination.labels["app"] == "ratings" && source.labels["app"]=="reviews" && source.labels["version"] == "v3"
  actions:
  - handler: denyreviewsv3handler.denier
    instances: [ denyreviewsv3request.checknothing ]
EOF
```



