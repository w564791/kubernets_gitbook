# 审计

`kubernetes`提供相应的安全方面的以时间顺序排列的审计功能,记录了各个用户,管理员或者其他系统组件的活动,其内容包含如下:

- 发生了什么
- 什么时候发生的
- 谁发起的
- 引起了什么后果
- 哪里观察到的
- 从哪里开始的
- 去了哪儿

为`kube-apiserver`执行审计,每个阶段的请求都会生成一个事件,然后根据某个策略对其进行预处理然后写入后端,策略确定记录的内容,后端保留记录,

每个请求都能用相关的阶段记录,已知的阶段是:

- `RequestReceived` : 审计处理程序收到请求后立即生成时间的阶段,以及在处理程序链下委托之前生成事件的阶段
- `ResponseStarted` :一旦发送响应头,但在发送响应主体之前,此阶段仅针对长时间运行的请求(监控)生成
- `ResponseComplete` :响应正文已完成，不再发送字节。 
- `Panic` :发生Panic 事件

# 审计策略

审计策略定义了应记录哪些事件以及应包含哪些数据的规则 ,审核策略对象结构在[`audit.k8s.io`API组中](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apiserver/pkg/apis/audit/v1beta1/types.go)定义  ,处理事件时，会按顺序将其与规则列表进行比较。第一个匹配规则设置事件的“审计级别”。已知的审计级别是： 

- `None` - 不记录符合此规则的事件。
- `Metadata` - 记录请求元数据（请求用户，时间戳，资源，动词等），但不是请求或响应正文。
- `Request` - 记录事件元数据和请求正文，但不记录响应正文。这不适用于非资源请求。
- `RequestResponse` - 记录事件元数据，请求和响应主体。这不适用于非资源请求。

使用--audit-policy-file 参数为`kube-apiserver`配置日志审计,如果省略该标志，则不记录任何事件 ,请注意，**必须**在审核策略文件中提供该`rules`字段 ,没有规则的策略被视为非法 

以下是一个示例审计策略文件： 

```yaml
# audit/audit-policy.yaml  
apiVersion: audit.k8s.io/v1beta1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"

```

您可以使用最小审计策略文件来记录`Metadata`级别的所有请求： 

```yaml
# Log all requests at the Metadata level.
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
```

# 审计后端

审计后端将审计事件持久保存到外部存储。[Kube-apiserver](https://kubernetes.io/docs/admin/kube-apiserver)提供了两个后端： 

- 记录后端，将事件写入磁盘
- Webhook后端，它将事件发送到外部API

在这两种情况下，审计事件结构都由`audit.k8s.io`API组中的API 定义 。API的当前版本是 [`v1beta1`](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/apiserver/pkg/apis/audit/v1beta1/types.go)。 

### 记录后端

日志后端将审核事件写入JSON格式的文件。您可以使用以下[kube-apiserver](https://kubernetes.io/docs/admin/kube-apiserver)标志配置日志审计后端：

- `--audit-log-path`指定日志后端用于写入审核事件的日志文件路径。不指定此标志会禁用日志后端。`-`意味着标准
- `--audit-log-maxage` 定义了保留旧审核日志文件的最大天数
- `--audit-log-maxbackup` 定义要保留的最大审核日志文件数
- `--audit-log-maxsize` 在轮换之前定义审计日志文件的最大大小（以兆字节为单位）

### `Webhook`后端

`Webhook`后端将审计事件发送到远程API，该API被假定为与[kube-apiserver](https://kubernetes.io/docs/admin/kube-apiserver)公开的API相同。您可以使用以下kube-apiserver标志配置webhook审计后端：

- `--audit-webhook-config-file`指定具有`webhook`配置的文件的路径。Webhook配置实际上是一个[kubeconfig](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)。
- `--audit-webhook-initial-backoff`指定在重试之前第一次失败请求之后等待的时间。随后的请求将以指数退避重试。

`webhook`配置文件使用`kubeconfig`格式指定服务的远程地址和用于连接它的凭据。

## 日志收集器示例

### 使用fluentd从日志文件中收集和分发审核事件

[Fluentd](http://www.fluentd.org/)是统一日志记录层的开源数据收集器。在此示例中，我们将使用fluentd按不同的命名空间拆分审计事件。 

在apiserver节点安装fluentd以及fluent-plugin-forest ,fluent-plugin-rewrite-tag-filter 模块

Fluent-plugin-forest和fluent-plugin-rewrite-tag-filter是fluentd的插件。您可以从[fluentd的插件管理中](https://docs.fluentd.org/v0.12/articles/plugin-management)获取有关插件安装的详细信息。 

1.为fluentd创建配置文件:

```
# cat <<EOF > /etc/fluentd/config
# fluentd conf runs in the same host with kube-apiserver
<source>
    @type tail
    # audit log path of kube-apiserver
    path /var/log/kube-audit
    pos_file /var/log/audit.pos
    format json
    time_key time
    time_format %Y-%m-%dT%H:%M:%S.%N%z
    tag audit
</source>

<filter audit>
    #https://github.com/fluent/fluent-plugin-rewrite-tag-filter/issues/13
    @type record_transformer
    enable_ruby
    <record>
     namespace ${record["objectRef"].nil? ? "none":(record["objectRef"]["namespace"].nil? ? "none":record["objectRef"]["namespace"])}
    </record>
</filter>

<match audit>
    # route audit according to namespace element in context
    @type rewrite_tag_filter
    rewriterule1 namespace ^(.+) ${tag}.$1
</match>

<filter audit.**>
   @type record_transformer
   remove_keys namespace
</filter>

<match audit.**>
    @type forest
    subtype file
    remove_prefix audit
    <template>
        time_slice_format %Y%m%d%H
        compress gz
        path /var/log/audit-${tag}.*.log
        format json
        include_time_key true
    </template>
</match>
```

2.启动fluentd

```
$ fluentd -c /etc/fluentd/config  -vv
```

3.使用以下选项启动kube-apiserver： 

```
--audit-policy-file=/etc/kubernetes/audit-policy.yaml --audit-log-path=/var/log/kube-audit --audit-log-format=json
```

4. 检查对不同命名空间的审核 `/var/log/audit-*.log` 

    

### 使用logstash从webhook后端收集和分发审核事件

[Logstash](https://www.elastic.co/products/logstash)是一种开源的服务器端数据处理工具。在此示例中，我们将使用logstash从webhook后端收集审核事件，并将不同用户的事件保存到不同的文件中。 

1. 安装[logstash](https://www.elastic.co/guide/en/logstash/current/installing-logstash.html)

2. 为logstash创建配置文件 

   

```
input{
    http{
        #TODO, figure out a way to use kubeconfig file to authenticate to logstash
        #https://www.elastic.co/guide/en/logstash/current/plugins-inputs-http.html#plugins-inputs-http-ssl
        port=>8888
    }
}
filter{
    split{
        # Webhook audit backend sends several events together with EventList
        # split each event here.
        field=>[items]
        # We only need event subelement, remove others.
        remove_field=>[headers, metadata, apiVersion, "@timestamp", kind, "@version", host]
    }
    mutate{
        rename => {items=>event}
    }
}
output{
    file{
        # Audit events from different users will be saved into different files.
        path=>"/var/log/kube-audit-%{[event][user][username]}/audit"
    }
}
```

3.启动logstash 

```
$ bin/logstash -f /etc/logstash/config --path.settings /etc/logstash/
```

4. 为kube-apiserver webhook审计后端创建一个[kubeconfig文件](https://kubernetes.io/docs/tasks/access-application-cluster/authenticate-across-clusters-kubeconfig/) 



```
$ cat < /etc/kubernetes/audit-webhook-kubeconfig 
apiVersion: v1 
clusters:
- cluster: 
  server: http://:8888 
  name: logstash 
contexts:
- context: 
  cluster: logstash 
  user: "" 
  name: default-context 
current-context: default-context 
kind: Config 
preferences: {} 
users: [] 
```

5.使用以下选项启动kube-apiserver： 

```
--audit-policy-file=/etc/kubernetes/audit-policy.yaml --audit-webhook-config-file=/etc/kubernetes/audit-webhook-kubeconfig
```

6.检查logstash节点目录中的审核 `/var/log/kube-audit-*/audit` 

请注意，除了文件输出插件之外，logstash还具有各种输出，可让用户将数据路由到所需位置。例如，用户可以向包含全文搜索和分析的elasticsearch插件发出审计事件 

