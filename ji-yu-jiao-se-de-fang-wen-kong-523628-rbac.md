## 特点

* 基于角色的语法,简单易用
* svc-svc和最终用户到svc授权
* 灵通过角色和角色绑定中的自定义属性使其更加灵活

## 架构

![](/assets/rbac-istioimport.png)

RBAC引擎做工作内容如下

* 获取RBAC策略: rbac殷勤观察策略,如有变更,将对其进行更新
* 授权请求: 当一个请求到来时,请求的上下文被传递给rbac引擎,其根据策略评估请求的上下文,返回授权结果\(ALLOW 或者DENY\)

## 请求上下文\(Request context\)



