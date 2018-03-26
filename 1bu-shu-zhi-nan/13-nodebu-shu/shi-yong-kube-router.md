```
Kube-router is built around concept of watchers and controllers. Watchers use Kubernetes watch API to get notification on events related to create, update, delete of Kubernetes objects. Each watcher gets notification related to a particular API object. On receiving an event from API server, watcher broadcasts events. Controller registers to get event updates from the watchers and act up on the events.
```



kube-router 的核心概念是其watchers和controllers，watchers通过监控K8S的api变化，create，update，delete K8S对象，每个watcher都会获取特定的api对象相关的通知，当从API接受到事件后，watchers广播事件，controller对事件进行更新并处理



