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

## 命名空间级访问控制 {#namespace-level-access-control}

目标:指定命名空间中的所有服务\(或一组服务\),从另一命名空间的服务访问

在bookinfo示例中 productpage,reviews,details,ratings服务部署在default命名空间,ingress部署在istio-system命名空间,所以本利中需要开放default以及istio-system空间的权限

1.创建一个ServiceRole 命名为service-viewer,其对所有服务具有GET权限,但是限制条件为必须具有一定的标签

```
# cat << EOF |istioctl create -f -
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRole
metadata:
  name: service-viewer
  namespace: default
spec:
  rules:
  - services: ["*"]
    methods: ["GET"]
    constraints:
    - key: "app"
      values: ["productpage", "details", "reviews", "ratings"]
EOF
```

2.创建一个ServiceRoleBinding,将service-viewer分配给istio-system和default命名空间中的所有角色

```
# cat << EOF |istioctl create -f -
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRoleBinding
metadata:
  name: bind-service-viewer
  namespace: default
spec:
  subjects:
  - properties:
      namespace: "istio-system"
  - properties:
      namespace: "default"
  roleRef:
    kind: ServiceRole
    name: "service-viewer"
EOF
```

刷新productpage,可以看到页面正常返回,当以任意用户登录productpage时,此时使用了POST方法,页面返回如下内容

```
PERMISSION_DENIED:handler.rbac.istio-system:RBAC: permission denied.
```



