开始之前:

* 正确安装istio
* 安装[bookinfo](https://istio.io/docs/guides/bookinfo/)示例
* 启用bookinfo示例的serviceaccount

```
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo-add-serviceaccount.yaml)
```

此时请求productpage,可以看到左下角图书详细信息,以及右边页面的评价信息.

## 启用Istio RBAC {#enabling-istio-rbac}

```
# cat << EOF |istioctl create -f -
apiVersion: "config.istio.io/v1alpha2"
kind: authorization
metadata:
  name: requestcontext
  namespace: istio-system
spec:
  subject:
    user: source.user | ""
    groups: ""
    properties:
      app: source.labels["app"] | ""
      version: source.labels["version"] | ""
      namespace: source.namespace | ""
  action:
    namespace: destination.namespace | ""
    service: destination.service | ""
    method: request.method | ""
    path: request.path | ""
    properties:
      app: destination.labels["app"] | ""
      version: destination.labels["version"] | ""
---
apiVersion: "config.istio.io/v1alpha2"
kind: rbac
metadata:
  name: handler
  namespace: istio-system
spec:
  config_store_url: "k8s://"
---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: rbaccheck
  namespace: istio-system
spec:
  match: destination.namespace == "default"
  actions:
  - handler: handler.rbac
    instances:
    - requestcontext.authorization
EOF
```

如果你的命名空间不是default,请修改相应的字段

该文件还定了以request context,他是一个授权模板示例,其定义了rbac引擎的输入信息.

刷新productpage,可以看到如下信息

```
PERMISSION_DENIED:handler.rbac.istio-system:RBAC: permission denied.
```



