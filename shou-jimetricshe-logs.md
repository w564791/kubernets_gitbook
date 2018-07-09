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
3. Dispatch of _instances_ to _handlers _according to a set of _rules_

## 理解metrics配置





