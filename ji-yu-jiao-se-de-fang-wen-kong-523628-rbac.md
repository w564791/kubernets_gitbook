## 特点

* 基于角色的语法,简单易用
* svc-svc和最终用户到svc授权
* 灵通过角色和角色绑定中的自定义属性使其更加灵活

## 架构

![](/assets/rbac-istioimport.png)

RBAC引擎做工作内容如下

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



