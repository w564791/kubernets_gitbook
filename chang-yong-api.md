更新deployments镜像

```
curl -X PATCH --header 'Content-Type: application/strategic-merge-patch+json' --header 'Accept: application/json' --user-agent "chrome" -d '{"spec":{"template":{"spec":{"containers":[{"image":"nginx","name": "busybox-1"}]}}}}' 127.0.0.1:9090/apis/extensions/v1beta1/namespaces/default/deployments/busybox-1
```

get命名空间为pxsj，lebelselector=pxsj-app的rs历史记录

```
curl 127.0.0.1:9090/apis/extensions/v1beta1/namespaces/pxsj/replicasets?labelSelector=pxsj-app%3Daccount-service
```



