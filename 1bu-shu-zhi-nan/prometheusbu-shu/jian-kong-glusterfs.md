```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat glusterfs-export.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: glusterfs-exportor
  namespace: monitoring
  labels:
    k8s-app: glusterfs
spec:
  replicas: 1
  template:
    metadata:
      labels:
        k8s-app: glusterfs
    spec:
      containers:
      - name: glusterfs-exportor
        image: 54.223.110.70/kubernetes/heketi_exporter:latest
        ports:
          - containerPort: 9189
            protocol: TCP
        env:
        - name: HEKETI_CLI_SERVER
          value: "http://heketi.storage:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: glusterfs-exportor
  namespace: monitoring
  labels:
    k8s-app: glusterfs
spec:
  ports:
  - port: 9189
    targetPort: 9189
    name: http-metrics
  selector:
    k8s-app: glusterfs

```



