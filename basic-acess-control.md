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

此时使用jason用户登录,可以看到黑星评价,表示当前使用的是reviews的v2版本请求ratings

将其他用户登录或者不登录,可以看到红星评价,表示当前是reviews的v3版本请求到ratings

### 使用拒绝服务

实现目标:

* 切断对reviews的v3版本的请求

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

注意一下match规则,他将拒绝来自reviews具有v3标签对ratings的请求

```
match: destination.labels["app"] == "ratings" && source.labels["app"]=="reviews" && source.labels["version"] == "v3"
```

## 使用_白名单_访问控制 {#access-control-using-whitelists}

开始之前

* 删除上节的denier配置

```
cat <<EOF | istioctl delete -f -
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

* 此时除非以jason用户登录,能看到黑星评价意外,其他都只能看到红星评价,执行一下步骤以后,除非以jason用户登录,否则不能看到星级评价

1.配置adapter

```
cat <<EOF | istioctl delete -f -
apiVersion: config.istio.io/v1alpha2
kind: listchecker
metadata:
  name: whitelist
spec:
  # providerUrl: ordinarily black and white lists are maintained
  # externally and fetched asynchronously using the providerUrl.
  overrides: ["v1", "v2"]  # overrides provide a static list
  blacklist: false
EOF
```

2.创建listentry提取version标签

```
cat <<EOF | istioctl delete -f -
apiVersion: config.istio.io/v1alpha2
kind: listentry
metadata:
  name: appversion
spec:
  value: source.labels["version"]
EOF
```

3.启用whitelist检查ratings微服务

```
cat <<EOF | istioctl delete -f -
apiVersion: config.istio.io/v1alpha2
kind: rule
metadata:
  name: checkversion
spec:
  match: destination.labels["app"] == "ratings"
  actions:
  - handler: whitelist.listchecker
    instances:
    - appversion.listentry
EOF
```



