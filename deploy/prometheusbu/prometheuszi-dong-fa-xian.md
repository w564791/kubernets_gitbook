```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-discovery-service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: kubelet
  name: kubelet
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: https-metrics
    port: 10250
    protocol: TCP
    targetPort: 10250
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: kube-controller-manager
  name: kube-controller-manager-prometheus-discovery
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: http-metrics
    port: 10252
    protocol: TCP
    targetPort: 10252
  selector:
    k8s-app: kube-controller-manager
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: etcd
  name: kube-etcd-prometheus-discovery
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: api
    port: 2379
    protocol: TCP
    targetPort: 2379
  selector:
    k8s-app: etcd
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: kube-scheduler
  name: kube-scheduler-prometheus-discovery
  namespace: kube-system
spec:
  clusterIP: None
  ports:
  - name: http-metrics
    port: 10251
    protocol: TCP
    targetPort: 10251
  selector:
    k8s-app: kube-scheduler
  sessionAffinity: None
  type: ClusterIP

```



