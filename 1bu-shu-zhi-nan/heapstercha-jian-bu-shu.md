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

* 如果后续使用 kube-apiserver 或者 kubectl proxy 访问 grafana dashboard，则必须将 `GF_SERVER_ROOT_URL` 设置为 `/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana/`，否则后续访问grafana时访问时提示找不到`http://172.20.0.113:8086/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana/api/dashboards/home` 页面；

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

* 本处将influxdb配置文件/etc/config.toml文件内容写入 ConfigMap，最后挂载到镜像中

#### 1,配置influxdb-configmap

```
# cat influxdb-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: influxdb-config
  namespace: kube-system
data:
  config.toml: |
    reporting-disabled = true
    bind-address = ":8088"
    [meta]
      dir = "/data/meta"
      retention-autocreate = true
      logging-enabled = true
    [data]
      dir = "/data/data"
      wal-dir = "/data/wal"
      query-log-enabled = true
      cache-max-memory-size = 1073741824
      cache-snapshot-memory-size = 26214400
      cache-snapshot-write-cold-duration = "10m0s"
      compact-full-write-cold-duration = "4h0m0s"
      max-series-per-database = 1000000
      max-values-per-tag = 100000
      trace-logging-enabled = false
    [coordinator]
      write-timeout = "10s"
      max-concurrent-queries = 0
      query-timeout = "0s"
      log-queries-after = "0s"
      max-select-point = 0
      max-select-series = 0
      max-select-buckets = 0
    [retention]
      enabled = true
      check-interval = "30m0s"
    [admin]
      enabled = true
      bind-address = ":8083"
      https-enabled = false
      https-certificate = "/etc/ssl/influxdb.pem"
    [shard-precreation]
      enabled = true
      check-interval = "10m0s"
      advance-period = "30m0s"
    [monitor]
      store-enabled = true
      store-database = "_internal"
      store-interval = "10s"
    [subscriber]
      enabled = true
      http-timeout = "30s"
      insecure-skip-verify = false
      ca-certs = ""
      write-concurrency = 40
      write-buffer-size = 1000
    [http]
      enabled = true
      bind-address = ":8086"
      auth-enabled = false
      log-enabled = true
      write-tracing = false
      pprof-enabled = false
      https-enabled = false
      https-certificate = "/etc/ssl/influxdb.pem"
      https-private-key = ""
      max-row-limit = 10000
      max-connection-limit = 0
      shared-secret = ""
      realm = "InfluxDB"
      unix-socket-enabled = false
      bind-socket = "/var/run/influxdb.sock"
    [[graphite]]
      enabled = false
      bind-address = ":2003"
      database = "graphite"
      retention-policy = ""
      protocol = "tcp"
      batch-size = 5000
      batch-pending = 10
      batch-timeout = "1s"
      consistency-level = "one"
      separator = "."
      udp-read-buffer = 0
    [[collectd]]
      enabled = false
      bind-address = ":25826"
      database = "collectd"
      retention-policy = ""
      batch-size = 5000
      batch-pending = 10
      batch-timeout = "10s"
      read-buffer = 0
      typesdb = "/usr/share/collectd/types.db"
    [[opentsdb]]
      enabled = false
      bind-address = ":4242"
      database = "opentsdb"
      retention-policy = ""
      consistency-level = "one"
      tls-enabled = false
      certificate = "/etc/ssl/influxdb.pem"
      batch-size = 1000
      batch-pending = 5
      batch-timeout = "1s"
      log-point-errors = true
    [[udp]]
      enabled = false
      bind-address = ":8089"
      database = "udp"
      retention-policy = ""
      batch-size = 5000
      batch-pending = 10
      read-buffer = 0
      batch-timeout = "1s"
      precision = ""
    [continuous_queries]
      log-enabled = true
      enabled = true
      run-interval = "1s"
```

#### 2.配置influxdb-deployment

```
# cat influxdb-deployment.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-influxdb
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: influxdb
    spec:
      containers:
      - name: influxdb
        image: 111.9.116.131:5000/w564791/heapster-influxdb-amd64:v1.1.1
        volumeMounts:
        - mountPath: /data
          name: influxdb-storage
        - mountPath: /etc/
          name: influxdb-config
      volumes:
      - name: influxdb-storage
        emptyDir: {}
      - name: influxdb-config
        configMap:
          name: influxdb-config
```

## 执行所有文件

```
# kubectl create -f .
```

```
# kubectl get -f .
```

```
NAME                        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/monitoring-grafana   1         1         1            1           16h

NAME                     CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
svc/monitoring-grafana   10.254.147.116   <none>        80/TCP    16h

NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/heapster   1         1         1            1           16h

NAME          SECRETS   AGE
sa/heapster   1         16h

NAME                           AGE
clusterrolebindings/heapster   16h

NAME           CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
svc/heapster   10.254.121.179   <none>        80/TCP    16h

NAME                 DATA      AGE
cm/influxdb-config   1         16h

NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/monitoring-influxdb   1         1         1            1           16h

NAME                      CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
svc/monitoring-influxdb   10.254.61.66   <nodes>       8086:31086/TCP,8083:31083/TCP   16h
```

```
# kubectl  get pods -n kube-system |grep -E "heapster|monitor"
```

```
heapster-290061577-5kj1r               1/1       Running   0          16h
monitoring-grafana-1581303656-9w0nb    1/1       Running   0          16h
monitoring-influxdb-2399066898-sld2p   1/1       Running   0          16h
```

## 通过apiserver访问dashboard

```
https://192.168.103.143/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard/
```

## ![](/assets/dashboard-deploy.png)![](/assets/dashboard-pod.png)通过apiserver访问grafana-dashboard

```
https://192.168.103.143/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana
```

![](/assets/grafana-dashboard-pods.png)![](/assets/grafana-dashboard-cluster.png)

