

创建grafana-dashboard configmap

```
[root@ip-10-10-6-201 prometheus-kubernetes]# tree dashboard/
dashboard/
├── All-Nodes-dashboard.json
├── Deployment-dashboard.json
├── GlusterFS-dashboard.json
├── Kubernetes-cluster-dashboard.json
├── mysqld-dashboard.json
├── Nodes-dashboard.json
├── one-see-dashboard.json
├── Pods-dashboard.json
├── prometheus-datasource.json
├── Prometheus-Stats-dashboard.json
└── Resource-Requests-dashboard.json
[root@ip-10-10-6-201 prometheus-kubernetes]#kubectl create cm grafana-dashboard --from-file=dashboard/
```



