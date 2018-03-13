更新deployments镜像

```
curl -X PATCH --header 'Content-Type: application/strategic-merge-patch+json' --header 'Accept: application/json' --user-agent "chrome" -d '{"spec":{"template":{"spec":{"containers":[{"image":"nginx","name": "busybox-1"}]}}}}' 127.0.0.1:9090/apis/extensions/v1beta1/namespaces/default/deployments/busybox-1
```

get命名空间为pxsj，lebelselector=pxsj-app的rs历史记录

```
curl 127.0.0.1:9090/apis/extensions/v1beta1/namespaces/pxsj/replicasets?labelSelector=pxsj-app%3Daccount-service
```

Rollback

```
curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'Accept-Encoding: gzip' -d '{"kind":"DeploymentRollback","apiVersion":"extensions/v1beta1","name":"busybox-1","rollbackTo":{"revision":21}}' 127.0.0.1:9090/apis/extensions/v1beta1/namespaces/default/deployments/busybox-1/rollback
```

官网

https://kubernetes.io/docs/reference/generated/federation/extensions/v1beta1/operations/

