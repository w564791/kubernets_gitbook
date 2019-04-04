使用EFK收集展示集群日志(Elasticsearch Fluent Kibana  )

本处仅说明Fluent配置,其他配置参考官方文档.

本处示例基础镜像来自官方[github](https://github.com/fluent/fluentd-kubernetes-daemonset)

在官方镜像的基础上做了filter规则修改,修改后的`Dockerfile`如下,修改后的镜像为`w564791/fluentd-elasticsearch:latest`,可以直接使用

```dockerfile
FROM w564791/fluentd:elasticsearch-v5
RUN rm -f /fluentd/etc/fluent.conf && rm -f /fluentd/etc/kubernetes.conf
ADD  fluent.conf /fluentd/etc/fluent.conf
ADD kubernetes.conf /fluentd/etc/kubernetes.conf
ENTRYPOINT /bin/entrypoint.sh /fluentd/entrypoint.sh
```

修改后的`fluent.conf`内容如下

```ruby
@include kubernetes.conf
<label @OUTPUT>
<match **>
   @type elasticsearch
   @id out_es
   @log_level info
   include_tag_key true
   host "#{ENV['FLUENT_ELASTICSEARCH_HOST']}"
   port "#{ENV['FLUENT_ELASTICSEARCH_PORT']}"
   scheme "#{ENV['FLUENT_ELASTICSEARCH_SCHEME'] || 'http'}"
   ssl_verify "#{ENV['FLUENT_ELASTICSEARCH_SSL_VERIFY'] || 'true'}"
   user "#{ENV['FLUENT_ELASTICSEARCH_USER']}"
   password "#{ENV['FLUENT_ELASTICSEARCH_PASSWORD']}"
   reload_connections "#{ENV['FLUENT_ELASTICSEARCH_RELOAD_CONNECTIONS'] || 'true'}"
   logstash_prefix "#{ENV['FLUENT_ELASTICSEARCH_LOGSTASH_PREFIX'] || 'logstash'}"
   logstash_format true
   type_name fluentd
   buffer_chunk_limit "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_CHUNK_LIMIT_SIZE'] || '2M'}"
   buffer_queue_limit "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_QUEUE_LIMIT_LENGTH'] || '32'}"
   flush_interval "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_FLUSH_INTERVAL'] || '5s'}"
   max_retry_wait "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_RETRY_MAX_INTERVAL'] || '30'}"
   disable_retry_limit
   num_threads "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_FLUSH_THREAD_COUNT'] || '8'}"
</match>
</label>

```

修改后的`kubernetes.conf`如下

```ruby
<match fluent.**>
  @type null
</match>

<source>
  @type tail
  @id in_tail_container_logs
  path /var/log/containers/*.log
  pos_file /var/log/fluentd-containers.log.pos
  tag kubernetes.*
  read_from_head true
  format json
  time_format %Y-%m-%dT%H:%M:%S.%NZ
  @label @CONCAT
</source>

<label @LOGCONCAT>
  <filter kubernetes.**>
    @type kubernetes_metadata
    @id filter_kube_metadata
  </filter>
  <match kubernetes.**>
    @type relabel
    @label @OUTPUT
  </match>
</label>

<label @CONCAT>
  <filter kubernetes.**>
    @type concat
    key log
    stream_identity_key container_id
    # 匹配ERROR开始行
    multiline_start_regexp /^\d{4}\S\d{1,2}\S\d{1,2}.*ERROR/  
    # 此处匹配以空格,java,Caused by,The last,com开头的行,与ERROR行合并为一行,如果有其他字段,需要修改此处
    continuous_line_regexp /^(\s+|java|Caused by:|The last|com)/
  </filter>
  <match kubernetes.**>
    @type relabel
    @label @LOGCONCAT
  </match>
</label>

```

k8s直接运行[此处](../yaml/fluentd-daemonset-elasticsearch-rbac.yaml)`yaml`