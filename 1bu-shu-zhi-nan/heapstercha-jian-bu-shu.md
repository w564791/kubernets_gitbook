本处使用到的yaml文件,[跳转下载](https://github.com/w564791/Kubernetes-Cluster/tree/master/yaml/heapster)

## 配置 grafana-deployment

```
# cat grafana-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-grafana
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: grafana
    spec:
      containers:
      - name: grafana
        image: 111.9.116.131:5000/w564791/heapster-grafana-amd64:v4.0.2
        ports:
          - containerPort: 3000
            protocol: TCP
        volumeMounts:
        - mountPath: /var
          name: grafana-storage
        env:
        - name: INFLUXDB_HOST
          value: monitoring-influxdb
        - name: GRAFANA_PORT
          value: "3000"
          # The following env variables are required to make Grafana accessible via
          # the kubernetes api-server proxy. On production clusters, we recommend
          # removing these env variables, setup auth for grafana, and expose the grafana
          # service using a LoadBalancer or a public IP.
        - name: GF_AUTH_BASIC_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_SERVER_ROOT_URL
          # If you're only using the API Server proxy, set this value instead:
          value: /api/v1/proxy/namespaces/kube-system/services/monitoring-grafana/
          #value: /
      volumes:
      - name: grafana-storage
        emptyDir: {}
```

## 配置 heapster-deployment

#### 1.配置heapster-rbac

```
# cat heapster-rbac.yaml
```

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
subjects:
  - kind: ServiceAccount
    name: heapster
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

#### 2.配置heapster-deployment

```
# cat heapster-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system

---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
subjects:
  - kind: ServiceAccount
    name: heapster
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
[root@k8s-1 influxdb]# cat heapster-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: heapster
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: heapster
    spec:
      serviceAccountName: heapster
      volumes:
       - hostPath:
          path: /etc/hosts
         name: ssl-certs-hosts
      containers:
      - name: heapster
        image: 111.9.116.131:5000/w564791/heapster-amd64:v1.3.0-beta.1
        imagePullPolicy: IfNotPresent
        volumeMounts:
         - mountPath: /etc/hosts
           name: ssl-certs-hosts
           readOnly: true
        command:
        - /heapster
        - --source=kubernetes:https://k8s-1
        - --sink=influxdb:http://monitoring-influxdb:8086

```

## 配置 influxdb-deployment



