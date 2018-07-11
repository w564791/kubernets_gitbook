### 在开始之前

* 需要正确部署istio\(noauth\)
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序
* 启用mtls
* 运行一下命令创建sa,并且重新部署productpage

```
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo-add-serviceaccount.yaml)
```

* 启用default命名空间的mtls

```
#cat <<EOF | istioctl create -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-1"
  namespace: "default"
spec:
  peers:
  - mtls:
EOF
```

* 允许default命名空间内所有svc的mtls

```
cat <<EOF | istioctl create -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-1"
  namespace: "default"
spec:
  host: "*.default.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

### 使用拒绝访问控制

示例目标:

* details服务拒绝来自productpage的请求

1.当前请求productpage,可以看到左下角图书详细部分,改部分由details服务提供

2.明确拒绝从productpage请求到details

```
cat <<EOF | istioctl create -f -
apiVersion: "config.istio.io/v1alpha2"
kind: denier
metadata:
  name: denyproductpagehandler
spec:
  status:
    code: 7
    message: Not allowed
---
apiVersion: "config.istio.io/v1alpha2"
kind: checknothing
metadata:
  name: denyproductpagerequest
spec:
---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: denyproductpage
spec:
  match: destination.labels["app"] == "details" && source.user == "cluster.local/ns/default/sa/bookinfo-productpage"
  actions:
  - handler: denyproductpagehandler.denier
    instances: [ denyproductpagerequest.checknothing ]
EOF
```

注意以下match规则,它将匹配来自cluster.local/ns/default/sa/bookinfo-productpage的sa服务的请求,如果ns不是default,请替换source.user中的default字段

```
match: destination.labels["app"] == "details" && source.user == "cluster.local/ns/default/sa/bookinfo-productpage"
```

刷新productpage页面,你会看到这个消息在页面的左下部分,"",这证实从productpage到details的请求被拒绝.

### 清理现场

```
#cat <<EOF | istioctl delete -f -
apiVersion: "config.istio.io/v1alpha2"
kind: denier
metadata:
  name: denyproductpagehandler
spec:
  status:
    code: 7
    message: Not allowed
---
apiVersion: "config.istio.io/v1alpha2"
kind: checknothing
metadata:
  name: denyproductpagerequest
spec:
---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: denyproductpage
spec:
  match: destination.labels["app"] == "details" && source.user == "cluster.local/ns/default/sa/bookinfo-productpage"
  actions:
  - handler: denyproductpagehandler.denier
    instances: [ denyproductpagerequest.checknothing ]
EOF
# istioctl delete DestinationRule example-1 -n default
# istioctl delete policy example-1 -n default
```

### 遇到的坑:

如果不启用mtls,将会在`istio-policy`服务中看到如下错误

```
input set condition evaluation error: id='6', error='lookup failed: 'source.user''
```



