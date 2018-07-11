## 特点

* 基于角色的语法,简单易用
* svc-svc和最终用户到svc授权
* 灵通过角色和角色绑定中的自定义属性使其更加灵活

## 架构

![](/assets/rbac-istioimport.png)

```
RBAC引擎做工作内容如下
```

* 获取RBAC策略: rbac殷勤观察策略,如有变更,将对其进行更新
* 授权请求: 当一个请求到来时,请求的上下文\(request context\)被传递给rbac引擎,其根据策略评估请求的上下文,返回授权结果\(ALLOW 或者DENY\)

## 请求上下文\(Request context\)

request context为实例提供请求模板,request context包含请求认证模块的所有请求和环境信息,尤其是如下两部分:

* **subject: **包含主叫方的身份列表\(list\),包含了"user","groups",或者其他属性,例如namespace,service

* **action: **指定"service如何被访问",期包含"namespace","service","path","method";以及其属性

如下是一个request context示例模板

```
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
      service: source.service | ""
      namespace: source.namespace | ""
  action:
    namespace: destination.namespace | ""
    service: destination.service | ""
    method: request.method | ""
    path: request.path | ""
    properties:
      version: request.headers["version"] | ""
```

## Istio RBAC 策略 {#istio-rbac-policy}

Istio RBAC 采用`ServiceRole`以及`ServiceRoleBinding,`其类似于kubernetes的CustomResourceDefinition \(CRD\)对象

* `ServiceRole`定义了在网格中访问服务的角色

* `ServiceRoleBinding`为对象授予角色  \(e.g., a user, a group, a service\).

## ServiceRole

一个`ServiceRole`包含了可能不仅一个规则的列表,每个规则包含如下标准字段

* **services** 关于service名称的列表, 这是和 "request context"中的`action.service`匹配
* **methods **请求方法列表,匹配"request context"中的`action.method`字段,为HTTP或者gRPC方法

* **paths **HTTP请求列表,匹配"request context"中的`action.path`字段

ServiceRole只适用于在metadata中指定namespace,services和methods是rules的必要字段,path为可选字段,如果没有指派或者设置为\*,那么将指配为"any"

例如,这里有一个例子, servicerole名称为service-admin,其将拥有default命名空间的所有service的完全请求权限

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRole
metadata:
  name: service-admin
  namespace: default
spec:
  rules:
  - services: ["*"]
    methods: ["*"]
```

如下例子,servicerole名称为products-viewer,在default命名空间内,对"products.default.svc.cluster.local"有只读权限\(GET 以及HEAD\)

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRole
metadata:
  name: products-viewer
  namespace: default
spec:
  rules:
  - services: ["products.default.svc.cluster.local"]
    methods: ["GET", "HEAD"]
```

另外,对于所有的字段,istio RBAC支持前缀匹配以及后缀匹配,如下servicerole示例,在default命名空间内,允许针对于以test-开头的所有服务的所有请求,针对于"bookstore.default.svc.cluster.local"的"\*/reviews"路径\(包含"/books/reviews","/events/books/reviews"等\)的只读\(READ\)请求

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRole
metadata:
  name: tester
  namespace: default
spec:
  rules:
  - services: ["test-*"]
    methods: ["*"]
  - services: ["bookstore.default.svc.cluster.local"]
    paths: ["*/reviews"]
    methods: ["GET"]
```

在ServiceRole中,namespace+services+paths+methods定义了"服务如何被允许请求",在某些情况下,可能需要额外的功能限制,例如,规则可能只适合于某个版本,或者其只适用于标记了foo标签的服务,我们可以通过自定义字段,轻松指定这些约束.

如下示例,被命名为products-viewer-version的ServiceRole,增加了约束条件,将version限制为v1或者v2, version条件由request context的`"action.properties.version"`字段提供

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRole
metadata:
  name: products-viewer-version
  namespace: default
spec:
  rules:
  - services: ["products.default.svc.cluster.local"]
    methods: ["GET", "HEAD"]
    constraints:
    - key: "version"
      values: ["v1", "v2"]
```

## ServiceRoleBinding

规范的ServiceRoleBinding包含如下2部分

* **roleRef **指定**同一命名空间**的ServiceRole资源

* **subjects **分配角色的的对象列表,其主体可以是user或者group,也可以是一组属性,\(“user” 或者“group” 或 “properties”\)必包含其一,并且必须匹配request context自subject字段

如下示例,命名为test-binding-products的ServiceRoleBinding资源,在abc命名空间中绑定了products-viewer的ServiceRole,以及alice@yahoo.com用户,以及reviews.abc.svc.cluster.local服务

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRoleBinding
metadata:
  name: test-binding-products
  namespace: default
spec:
  subjects:
  - user: "alice@yahoo.com"
  - properties:
      service: "reviews.abc.svc.cluster.local"
      namespace: "abc"
  roleRef:
    kind: ServiceRole
    name: "products-viewer"
```

在想要公开服务访问的情况下,可以将subject字段的user设置为\*,其将为所有用户以及服务分配这个ServiceRole

```
apiVersion: "config.istio.io/v1alpha2"
kind: ServiceRoleBinding
metadata:
  name: binding-products-allusers
  namespace: default
spec:
  subjects:
  - user: "*"
  roleRef:
    kind: ServiceRole
    name: "products-viewer"
```

## Enabling Istio RBAC {#enabling-istio-rbac}

Istio RBAC可以通过如下方法被启用,该规则包含2个部分,

* 第一个部分定义rbac handler,共有个块,"config\_store\_url"以及"cache\_duration","config\_store\_url"指定rbac引擎从哪里获取rbac策略,默认的值是"k8s://",当然也可以设置为本地目录"fs:///tmp/testdata/configroot",`"cache_duration"`指定其授权结果在客户端上缓存的持续时间,默认值为1分钟
* 第二部分定义了一个rule,其指定了使用哪个request context

如下示例.在default命名空间中启用rbac,并且缓存时间为30秒,其使用的request context为本文最开始定义的request context

```
apiVersion: "config.istio.io/v1alpha2"
kind: rbac
metadata:
  name: handler
  namespace: istio-system
spec:
  config_store_url: "k8s://"
  cache_duration: "30s"
---
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: rbaccheck
  namespace: istio-system
spec:
  match: destination.namespace == "default"
  actions:
  # handler and instance names default to the rule's namespace.
  - handler: handler.rbac
    instances:
    - requestcontext.authorization
```



