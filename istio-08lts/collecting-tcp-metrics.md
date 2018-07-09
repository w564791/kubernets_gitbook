##  收集TCP服务的metrics

本次任务展示如何在服务网格中配置istio自动的收集TCP服务的metrics,在任务最后一个新的metric将会被启用

## 开始之前

- 正确部署istio

- 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序,并且bookinfo部署在default命名空间,如果你部署在其他ns,你需要额外的配置示例中的文件

  

## 收集新的数据

1.创建新的YAML文件,配置只是istio如何生成和收集metrics,保存文件名为`tcp_telemetry.yaml`

```yaml
# Configuration for a metric measuring bytes sent from a server
# to a client
apiVersion: "config.istio.io/v1alpha2"
kind: metric
metadata:
  name: mongosentbytes
  namespace: default
spec:
  value: connection.sent.bytes | 0 # uses a TCP-specific attribute
  dimensions:
    source_service: source.service | "unknown"
    source_version: source.labels["version"] | "unknown"
    destination_version: destination.labels["version"] | "unknown"
  monitoredResourceType: '"UNSPECIFIED"'
---
# Configuration for a metric measuring bytes sent from a client
# to a server
apiVersion: "config.istio.io/v1alpha2"
kind: metric
metadata:
  name: mongoreceivedbytes
  namespace: default
spec:
  value: connection.received.bytes | 0 # uses a TCP-specific attribute
  dimensions:
    source_service: source.service | "unknown"
    source_version: source.labels["version"] | "unknown"
    destination_version: destination.labels["version"] | "unknown"
  monitoredResourceType: '"UNSPECIFIED"'
---
# Configuration for a Prometheus handler
apiVersion: "config.istio.io/v1alpha2"
kind: prometheus
metadata:
  name: mongohandler
  namespace: default
spec:
  metrics:
  - name: mongo_sent_bytes # Prometheus metric name
    instance_name: mongosentbytes.metric.default # Mixer instance name (fully-qualified)
    kind: COUNTER
    label_names:
    - source_service
    - source_version
    - destination_version
  - name: mongo_received_bytes # Prometheus metric name
    instance_name: mongoreceivedbytes.metric.default # Mixer instance name (fully-qualified)
    kind: COUNTER
    label_names:
    - source_service
    - source_version
    - destination_version
---
# Rule to send metric instances to a Prometheus handler
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: mongoprom
  namespace: default
spec:
  match: context.protocol == "tcp"
         && destination.service == "mongodb.default.svc.cluster.local"
  actions:
  - handler: mongohandler.prometheus
    instances:
    - mongoreceivedbytes.metric
    - mongosentbytes.metric

```

2.push该配置

```shell
$ istioctl create -f tcp_telemetry.yaml
```

3.配置bookinfo使用MongoDB



安装`ratings`的v1版本

```shell
$ kubectl apply -f samples/bookinfo/kube/bookinfo-ratings-v2.yaml
```

部署MongoDB

```shell
$ kubectl apply -f samples/bookinfo/kube/bookinfo-db.yaml
```

把流量导向`ratings`的v2版本

```
$ istioctl create -f samples/bookinfo/kube/route-rule-ratings-db.yaml
```

在浏览器中请求bookinfo的productpage

查询Prometheus中的数据(本例中去掉了metric中的mongo字样)

![1531126847435](D:\tianbao\gitlab\code\kubernets_gitbook\assets\1531126847435.png)

## 了解TCP数据收集

TCP数据收集方式和前一章[收集metrics和logs](../shou-jimetricshe-logs.md)方法相同

## TCP属性

![Attribute Generation Flow for TCP Services in an Istio Mesh.](D:\tianbao\gitlab\code\kubernets_gitbook\assets\istio-tcp-attribute-flow.svg) 