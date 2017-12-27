Prometheus授权文件

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-k8s
  namespace: monitoring
```

Prometheus-svc

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-k8s-svc.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    prometheus: k8s
  name: prometheus-k8s
  namespace: monitoring
spec:
  ports:
  - name: web
    nodePort: 30900
    port: 9090
    protocol: TCP
    targetPort: web
  selector:
    prometheus: k8s
  sessionAffinity: None
  type: NodePort
```

Prometheus-statefulset（此处使用了storage-class，需要先部署glusterfs）

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-statefulset.yaml
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  labels:
    prometheus: k8s
  name: prometheus-k8s
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: prometheus
      prometheus: k8s
  serviceName: prometheus-operated
  template:
    metadata:
      labels:
        app: prometheus
        prometheus: k8s
    spec:
      containers:
      - args:
        - --config.file=/etc/prometheus/config/prometheus.yaml
        - --storage.tsdb.path=/var/prometheus/data
        - --storage.tsdb.retention=720h
        - --web.route-prefix=/
        - --web.enable-lifecycle
        - --web.enable-admin-api
        image: 54.223.110.70/kubernetes/prometheus:v2.0.0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 10
          httpGet:
            path: /status
            port: web
            scheme: HTTP
          initialDelaySeconds: 300
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 3
        name: prometheus
        ports:
        - containerPort: 9090
          name: web
          protocol: TCP
        readinessProbe:
          failureThreshold: 6
          httpGet:
            path: /status
            port: web
            scheme: HTTP
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 3
        resources:
          requests:
            memory: 5Gi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/prometheus/config
          name: config
          readOnly: true
        - mountPath: /etc/prometheus/rules
          name: rules
          readOnly: true
        - mountPath: /var/prometheus/data
          name: prometheus-k8s-db
          subPath: prometheus-db
      - args:
        - -webhook-url=http://localhost:9090/-/reload
        - -volume-dir=/etc/prometheus/config
        - -volume-dir=/etc/prometheus/rules
        image: 54.223.110.70/kubernetes/configmap-reload:v0.0.1
        imagePullPolicy: IfNotPresent
        name: prometheus-config-reloader
        resources:
          limits:
            cpu: 5m
            memory: 10Mi
        volumeMounts:
        - mountPath: /etc/prometheus/config
          name: config
          readOnly: true
        - mountPath: /etc/prometheus/rules
          name: rules
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      serviceAccount: prometheus-k8s
      serviceAccountName: prometheus-k8s
      securityContext:
        runAsUser: 0
        fsGroup: 0
      terminationGracePeriodSeconds: 600
      volumes:
      - configMap:
          defaultMode: 420
          name: prometheus-k8s
        name: config
      - configMap:
          defaultMode: 420
          name: prometheus-k8s-rules
        name: rules
  updateStrategy:
    type: RollingUpdate
  volumeClaimTemplates:
  - metadata:
      name: prometheus-k8s-db
      annotations:
        volume.beta.kubernetes.io/storage-class: gluster-heketi
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 30Gi
```

Prometheus-cm

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-k8s-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-k8s
  namespace: monitoring
data:
  prometheus.yaml: |
    global:
      evaluation_interval: 30s
      scrape_interval: 30s
      external_labels: {}
    rule_files:
    - /etc/prometheus/rules/*.rules
    scrape_configs:
    - job_name: monitoring/alertmanager/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_alertmanager
        regex: main
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: web
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - target_label: endpoint
        replacement: web
    - job_name: monitoring/kube-apiserver/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - default
      scrape_interval: 30s
      scheme: https
      tls_config:
        insecure_skip_verify: false
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        server_name: kubernetes
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_component
        regex: apiserver
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_provider
        regex: kubernetes
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: https
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_component
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: https
    - job_name: mysqld
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: mysqld
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_label_rds_mysql
        target_label: pod
        regex: (.+)
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_component
        target_label: job
        regex: (.+)
        replacement: ${1}
    - job_name: glusterfs
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: glusterfs
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
    - job_name: monitoring/kube-controller-manager/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kube-controller-manager
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics
    - job_name: monitoring/etcd/0
      honor_labels: false
      scheme: https
      tls_config:
        insecure_skip_verify: true
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: etcd
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: api
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: api
    - job_name: monitoring/kube-dns/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kube-dns
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics-skydns
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics-skydns
    - job_name: monitoring/kube-dns/1
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kube-dns
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics-dnsmasq
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics-dnsmasq
    - job_name: monitoring/kube-scheduler/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kube-scheduler
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics
    - job_name: monitoring/kube-state-metrics/0
      honor_labels: true
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kube-state-metrics
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics
    - job_name: monitoring/kubelet/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kubelet
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics
    - job_name: monitoring/kubelet/1
      honor_labels: true
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: kubelet
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: cadvisor
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: cadvisor
    - job_name: monitoring/node-exporter/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: node-exporter
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: http-metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: http-metrics
    - job_name: monitoring/traefik/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - kube-system
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_k8s_app
        regex: traefik-ingress-lb
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - source_labels:
        - __meta_kubernetes_service_label_k8s_app
        target_label: job
        regex: (.+)
        replacement: ${1}
      - target_label: endpoint
        replacement: metrics
    - job_name: monitoring/prometheus/0
      honor_labels: false
      kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - monitoring
      scrape_interval: 30s
      relabel_configs:
      - action: keep
        source_labels:
        - __meta_kubernetes_service_label_prometheus
        regex: k8s
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: web
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
      - target_label: endpoint
        replacement: web
    - job_name: 'kubernetes-service-endpoints'
      kubernetes_sd_configs:
      - role: endpoints
      relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
        action: replace
        target_label: __scheme__
        regex: (https?)
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
      - action: keep
        source_labels:
        - __meta_kubernetes_endpoint_port_name
        regex: metrics
      - source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: service
      - source_labels:
        - __meta_kubernetes_service_name
        target_label: job
        replacement: ${1}
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
    - job_name: kubernetes-nodes-cadvisor
      scrape_interval: 10s
      scrape_timeout: 10s
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
      metric_relabel_configs:
      - action: replace
        source_labels: [id]
        regex: '^/machine\.slice/machine-rkt\\x2d([^\\]+)\\.+/([^/]+)\.service$'
        target_label: rkt_container_name
        replacement: '${2}-${1}'
      - action: replace
        source_labels: [id]
        regex: '^/system\.slice/(.+)\.service$'
        target_label: systemd_service_name
        replacement: '${1}'
    alerting:
      alertmanagers:
      - path_prefix: /
        scheme: http
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - monitoring
        relabel_configs:
        - action: keep
          source_labels:
          - __meta_kubernetes_service_name
          regex: alertmanager-main
        - action: keep
          source_labels:
          - __meta_kubernetes_endpoint_port_name
          regex: web

```

Prometheus-rules

Prometheus-discover

Prometheus-etcd监控

Prometheus-kubelet监控

