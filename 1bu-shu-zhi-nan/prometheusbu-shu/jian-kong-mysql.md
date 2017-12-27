```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat mysql-export.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mysql-exportor-1
  namespace: monitoring
  labels:
    k8s-app: mysqld
spec:
  replicas: 1
  template:
    metadata:
      labels:
        k8s-app: mysqld
        rds-mysql: "prod-vcity-user.cxzieaqx4sdw.rds.cn-north-1.amazonaws.com.cn-1"
    spec:
      containers:
      - name:  mysql-exportor
        image: 54.223.110.70/kubernetes/mysqld-exporter:latest
        ports:
          - containerPort: 9104
            protocol: TCP
        env:
        - name: DATA_SOURCE_NAME
          value: 'user:pass@(prod-vcity-user.cxzieaqx4sdw.rds.cn-north-1.amazonaws.com.cn:3306)/'
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mysql-exportor-2
  namespace: monitoring
  labels:
    k8s-app: mysqld
spec:
  replicas: 1
  template:
    metadata:
      labels:
        k8s-app: mysqld
        rds-mysql: "prod-vcity-user.cxzieaqx4sdw.rds.cn-north-1.amazonaws.com.cn-2"
    spec:
      containers:
      - name: mysql-exportor
        image: 54.223.110.70/kubernetes/mysqld-exporter:latest
        ports:
          - containerPort: 9104
            protocol: TCP
        env:
        - name: DATA_SOURCE_NAME
          value: 'zbx_user:zbx_user#123@(prod-vcity-user.cxzieaqx4sdw.rds.cn-north-1.amazonaws.com.cn:3306)/'
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-exportor
  namespace: monitoring
  labels:
    k8s-app: mysqld
spec:
  ports:
  - port: 9104
    targetPort: 9104
    name: http-metrics
  selector:
    k8s-app: mysqld

```



