当启动kubelet 参数--anonymous-auth=false时,请求node需要带ca和token,使用如下方式访问:

```
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt  -H "Authorization: Bearer $Token" https://10.254.0.1/api/v1/nodes/192.168.178.128/proxy/metrics/cadvisor
```

删除集群内所有Evicted容器:

```
kubectl get pods --all-namespaces -ojson -a| jq -r '.items[] | select(.status.reason!=null) | select(.status.reason | contains("Evicted")) | .metadata.name + " " + .metadata.namespace' |xargs -n2 -l bash -c 'kubectl delete pods $0 --namespace=$1'
```



