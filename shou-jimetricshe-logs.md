本次任务展示如何在服务网格中自动的收集服务的一些遥测数据,在任务最后,一个新的metric和日志流会在网格中被启用.

## 在开始之前

* 正确安装istio

## 收集新的数据

1.创建新的yaml文件,配置新的metric和日志流,istio会自动的生成和收集相应的数据

```
#cat  new_telemetry.yaml

# Configuration for metric instances
apiVersion: "config.istio.io/v1alpha2"
kind: metric
metadata:
  name: doublerequestcount
  namespace: istio-system
spec:
  value: "2" # count each request twice
  dimensions:
    source: source.service | "unknown"
    destination: destination.service | "unknown"
    message: '"twice the fun!"'
  monitored_resource_type: '"UNSPECIFIED"'
---
# Configuration for a Prometheus handler
apiVersion: "config.istio.io/v1alpha2"
kind: prometheus
metadata:
  name: doublehandler
  namespace: istio-system
spec:
  metrics:
  - name: double_request_count # Prometheus metric name
    instance_name: doublerequestcount.metric.istio-system # Mixer instance name (fully-qualified)
    kind: COUNTER
    label_names:
    - source
    - destination
    - message
---
# Rule to send metric instances to a Prometheus handler
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: doubleprom
  namespace: istio-system
spec:
  actions:
  - handler: doublehandler.prometheus
    instances:
    - doublerequestcount.metric
---
# Configuration for logentry instances
apiVersion: "config.istio.io/v1alpha2"
kind: logentry
metadata:
  name: newlog
  namespace: istio-system
spec:
  severity: '"warning"'
  timestamp: request.time
  variables:
    source: source.labels["app"] | source.service | "unknown"
    user: source.user | "unknown"
    destination: destination.labels["app"] | destination.service | "unknown"
    responseCode: response.code | 0
    responseSize: response.size | 0
    latency: response.duration | "0ms"
  monitored_resource_type: '"UNSPECIFIED"'
---
# Configuration for a stdio handler
apiVersion: "config.istio.io/v1alpha2"
kind: stdio
metadata:
  name: newhandler
  namespace: istio-system
spec:
 severity_levels:
   warning: 1 # Params.Level.WARNING
 outputAsJson: true
---
# Rule to send logentry instances to a stdio handler
apiVersion: "config.istio.io/v1alpha2"
kind: rule
metadata:
  name: newlogstdio
  namespace: istio-system
spec:
  match: "true" # match for all requests
  actions:
   - handler: newhandler.stdio
     instances:
     - newlog.logentry
---
```

2.push新的配置

```
# istioctl create -f new_telemetry.yaml
```

1. 请求bookinfo的productpage页面

4.查看Prometheus的数据

![](/assets/Prometheus-dataimport.png)5.查看请求日志刘

```
# kubectl -n istio-system logs $(kubectl -n istio-system get pods -l istio-mixer-type=telemetry -o jsonpath='{.items[0].metadata.name}') mixer | grep \"instance\":\"newlog.logentry.istio-system\"
{"level":"warn","time":"2018-07-09T06:27:10.697204Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"1.228702ms","responseCode":200,"responseSize":5,"source":"unknown","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:27:10.698311Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"988.062µs","responseCode":200,"responseSize":5,"source":"istio-ingressgateway.istio-system.svc.cluster.local","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:27:23.700682Z","instance":"newlog.logentry.istio-system","destination":"istio-policy.istio-system.svc.cluster.local","latency":"1.640487ms","responseCode":200,"responseSize":108,"source":"istio-ingressgateway.istio-system.svc.cluster.local","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:27:23.700179Z","instance":"newlog.logentry.istio-system","destination":"istio-ingressgateway.istio-system.svc.cluster.local","latency":"9.294168ms","responseCode":200,"responseSize":1795,"source":"unknown","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:27:24.701967Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"1.890863ms","responseCode":200,"responseSize":5,"source":"unknown","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:27:24.709841Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"3.608709ms","responseCode":200,"responseSize":5,"source":"istio-ingressgateway.istio-system.svc.cluster.local","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:28:47.750879Z","instance":"newlog.logentry.istio-system","destination":"istio-policy.istio-system.svc.cluster.local","latency":"1.926194ms","responseCode":200,"responseSize":108,"source":"istio-ingressgateway.istio-system.svc.cluster.local","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:28:47.749796Z","instance":"newlog.logentry.istio-system","destination":"istio-ingressgateway.istio-system.svc.cluster.local","latency":"8.979151ms","responseCode":200,"responseSize":1802,"source":"unknown","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:28:48.752131Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"2.019855ms","responseCode":200,"responseSize":5,"source":"unknown","user":"unknown"}
{"level":"warn","time":"2018-07-09T06:28:48.758448Z","instance":"newlog.logentry.istio-system","destination":"istio-telemetry.istio-system.svc.cluster.local","latency":"2.018155ms","responseCode":200,"responseSize":5,"source":"istio-ingressgateway.istio-system.svc.cluster.local","user":"unknown"}
```

## 了解telemetry配置

在本次任务中,我们添加了istio的配置,其指示Mixer对于网格中的流量,自动的生成和报告系的metric和新的日志流

增加的配置受到Mixer功能中的3中因素控制:

1. 生成_instance_
2. 创建_handlers_处理生成的_instance_
3. Dispatch of _instances_ to _handlers \_according to a set of \_rules_

## 理解metrics配置

metrics配置指示Mixer将metric发送到Prometheus,他使用了3个配置块:_instance,handler,rule_

`kind: metric`块定义了名为`doublerequestcount`的metric,该实例配置告诉Mixer如何生成metric值,以及其他需求,当然,这些基于Envoy\(当然也包含Mixer自身\)

对于`doublerequestcount.metric`的每个instance,配置指示Mixer为instance提供值为2,这意味着该metric记录值等于收到请求的总数的2倍

为每个`doublerequestcount.metric`实例指定一组`dimensions,`Dimensions提供了根据查询不同的需求和方向对metrics进行切片,聚合和分析,例如,可能需要在对应用程序行为进行故障排除时仅考虑对特定目标服务的查询请求

配置指示Mixer根据属性值以及表面值填充这些`dimensions`的值,例如,对于`source`dimension,新的配置从source.service属性获取值,如果未获取到该值,rule会指示Mixer使用默认的""unknown"",对于`message`dimension,使用文字值"twice the fun!"

`kind: prometheus`块定义了一个名叫doublehandler的handler,该handler的spec配置了Prometheus的metric标准,该值可以由Prometheus处理,该配置定义了一个名为double\_request\_count的指标,同时Prometheus adapter将istio\_添加到命名空间之前,所以该metric在Prometheus中查询值为istio\_double\_request\_count,该metric有3个label,其与doublerequestcount.metric相匹配



