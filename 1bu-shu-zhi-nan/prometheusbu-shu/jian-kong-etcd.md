```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-discovery-etcd-ep.yaml
kind: Endpoints
apiVersion: v1
metadata: 
  name: etcd-pxsj
  labels:
    k8s-app: etcd
  name: etcd-pxsj
  namespace: kube-system
subsets:
- addresses:
  - ip: 10.10.6.90
  - ip: 10.10.5.105
  - ip: 10.10.6.201
  ports:
  - port: 2379
    name: api

```



