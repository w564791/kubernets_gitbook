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

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat prometheus-k8s-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-k8s-rules
  namespace: monitoring
data:
  alertmanager.rules: |
    groups:
    - name: alertmanager
      rules:
      - alert: FailedReload
        expr: alertmanager_config_last_reload_successful == 0
        for: 10m
        labels:
          severity: warning
        annotations:
          description: Reloading Alertmanager's configuration has failed for {{ $labels.namespace
            }}/{{ $labels.pod}}.
          summary: Alertmanager configuration reload has failed
  etcd3.rules: |
    groups:
    - name: etcd3
      rules:
      - alert: InsufficientMembers
        expr: count(up{job="etcd"} == 0) > (count(up{job="etcd"}) / 2 - 1)
        for: 3m
        labels:
          severity: critical
        annotations:
          description: If one more etcd member goes down the cluster will be unavailable
          summary: etcd cluster insufficient members
      - alert: NoLeader
        expr: etcd_server_has_leader{job="etcd"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          description: etcd member {{ $labels.instance }} has no leader
          summary: etcd member has no leader
      - alert: HighNumberOfLeaderChanges
        expr: increase(etcd_server_leader_changes_seen_total{job="etcd"}[1h]) > 3
        labels:
          severity: warning
        annotations:
          description: etcd instance {{ $labels.instance }} has seen {{ $value }} leader
            changes within the last hour
          summary: a high number of leader changes within the etcd cluster are happening
      - alert: HighNumberOfFailedGRPCRequests
        expr: sum(rate(etcd_grpc_requests_failed_total{job="etcd"}[5m])) BY (grpc_method)
          / sum(rate(etcd_grpc_total{job="etcd"}[5m])) BY (grpc_method) > 0.01
        for: 10m
        labels:
          severity: warning
        annotations:
          description: '{{ $value }}% of requests for {{ $labels.grpc_method }} failed
            on etcd instance {{ $labels.instance }}'
          summary: a high number of gRPC requests are failing
      - alert: HighNumberOfFailedGRPCRequests
        expr: sum(rate(etcd_grpc_requests_failed_total{job="etcd"}[5m])) BY (grpc_method)
          / sum(rate(etcd_grpc_total{job="etcd"}[5m])) BY (grpc_method) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          description: '{{ $value }}% of requests for {{ $labels.grpc_method }} failed
            on etcd instance {{ $labels.instance }}'
          summary: a high number of gRPC requests are failing
      - alert: GRPCRequestsSlow
        expr: histogram_quantile(0.99, rate(etcd_grpc_unary_requests_duration_seconds_bucket[5m]))
          > 0.15
        for: 10m
        labels:
          severity: critical
        annotations:
          description: on etcd instance {{ $labels.instance }} gRPC requests to {{ $labels.grpc_method
            }} are slow
          summary: slow gRPC requests
      - alert: HighNumberOfFailedHTTPRequests
        expr: sum(rate(etcd_http_failed_total{job="etcd"}[5m])) BY (method) / sum(rate(etcd_http_received_total{job="etcd"}[5m]))
          BY (method) > 0.01
        for: 10m
        labels:
          severity: warning
        annotations:
          description: '{{ $value }}% of requests for {{ $labels.method }} failed on etcd
            instance {{ $labels.instance }}'
          summary: a high number of HTTP requests are failing
      - alert: HighNumberOfFailedHTTPRequests
        expr: sum(rate(etcd_http_failed_total{job="etcd"}[5m])) BY (method) / sum(rate(etcd_http_received_total{job="etcd"}[5m]))
          BY (method) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          description: '{{ $value }}% of requests for {{ $labels.method }} failed on etcd
            instance {{ $labels.instance }}'
          summary: a high number of HTTP requests are failing
      - alert: HTTPRequestsSlow
        expr: histogram_quantile(0.99, rate(etcd_http_successful_duration_seconds_bucket[5m]))
          > 0.15
        for: 10m
        labels:
          severity: warning
        annotations:
          description: on etcd instance {{ $labels.instance }} HTTP requests to {{ $labels.method
            }} are slow
          summary: slow HTTP requests
      - alert: EtcdMemberCommunicationSlow
        expr: histogram_quantile(0.99, rate(etcd_network_member_round_trip_time_seconds_bucket[5m]))
          > 0.15
        for: 10m
        labels:
          severity: warning
        annotations:
          description: etcd instance {{ $labels.instance }} member communication with
            {{ $labels.To }} is slow
          summary: etcd member communication is slow
      - alert: HighNumberOfFailedProposals
        expr: increase(etcd_server_proposals_failed_total{job="etcd"}[1h]) > 5
        labels:
          severity: warning
        annotations:
          description: etcd instance {{ $labels.instance }} has seen {{ $value }} proposal
            failures within the last hour
          summary: a high number of proposals within the etcd cluster are failing
      - alert: HighFsyncDurations
        expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))
          > 0.5
        for: 10m
        labels:
          severity: warning
        annotations:
          description: etcd instance {{ $labels.instance }} fync durations are high
          summary: high fsync durations
      - alert: HighCommitDurations
        expr: histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m]))
          > 0.25
        for: 10m
        labels:
          severity: warning
        annotations:
          description: etcd instance {{ $labels.instance }} commit durations are high
          summary: high commit durations
  general.rules: |
    groups:
    - name: general
      rules:
      - alert: TargetDown
        expr: 100 * (count(up == 0) BY (job) / count(up) BY (job)) > 10
        for: 10m
        labels:
          severity: warning
        annotations:
          description: '{{ $value }}% or more of {{ $labels.job }} targets are down.'
          summary: Targets are down
      - alert: deploy has less than expected
        expr:  (kube_deployment_status_replicas_available{deployment!~"(go-pushsrv|php-pcron|promotion-service|pxsj-scheduler)"}/kube_deployment_spec_replicas)*100 <= 50
        labels:
          severity: warning
        annotations:
          description: '{{ $value }}%  of {{ $labels.deployment }} pod less than expected .'            
          summary: deploy has less than expected
      - alert: TooManyOpenFileDescriptors
        expr: 100 * (process_open_fds / process_max_fds) > 95
        for: 10m
        labels:
          severity: critical
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }} ({{
            $labels.instance }}) is using {{ $value }}% of the available file/socket descriptors.'
          summary: too many open file descriptors
      - record: instance:fd_utilization
        expr: process_open_fds / process_max_fds
      - alert: FdExhaustionClose
        expr: predict_linear(instance:fd_utilization[1h], 3600 * 4) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }} ({{
            $labels.instance }}) instance will exhaust in file/socket descriptors soon'
          summary: file descriptors soon exhausted
      - alert: FdExhaustionClose
        expr: predict_linear(instance:fd_utilization[10m], 3600) > 1
        for: 10m
        labels:
          severity: critical
        annotations:
          description: '{{ $labels.job }}: {{ $labels.namespace }}/{{ $labels.pod }} ({{
            $labels.instance }}) instance will exhaust in file/socket descriptors soon'
          summary: file descriptors soon exhausted
  kube-apiserver.rules: |
    groups:
    - name: kube-apiserver
      rules:
      - alert: K8SApiserverDown
        expr: absent(up{job="apiserver"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          description: Prometheus failed to scrape API server(s), or all API servers have
            disappeared from service discovery.
          summary: API server unreachable
      - alert: K8SApiServerLatency
        expr: histogram_quantile(0.99, sum(apiserver_request_latencies_bucket{verb!~"^(?:CONNECT|WATCHLIST|WATCH|PROXY)$",subresource!="log"})
          WITHOUT (instance, resource)) / 1e+06 > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          description: 99th percentile Latency for {{ $labels.verb }} requests to the
            kube-apiserver is higher than 1s.
          summary: Kubernetes apiserver latency is high
  kube-controller-manager.rules: |
    groups:
    - name: kube-controller-manager
      rules:
      - alert: K8SControllerManagerDown
        expr: absent(up{job="kube-controller-manager"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          description: There is no running K8S controller manager. Deployments and replication
            controllers are not making progress.
          runbook: https://coreos.com/tectonic/docs/latest/troubleshooting/controller-recovery.html#recovering-a-controller-manager
          summary: Controller manager is down
  kube-scheduler.rules: |
    groups:
    - name: kube-scheduler
      rules:
      - alert: K8SSchedulerDown
        expr: absent(up{job="kube-scheduler"} == 1)
        for: 5m
        labels:
          severity: critical
        annotations:
          description: There is no running K8S scheduler. New pods are not being assigned
            to nodes.
          runbook: https://coreos.com/tectonic/docs/latest/troubleshooting/controller-recovery.html#recovering-a-scheduler
          summary: Scheduler is down
  kubelet.rules: |
    groups:
    - name: kubelet
      rules:
      - alert: K8SNodeNotReady
        expr: kube_node_status_ready{condition="true"} == 0
        for: 1h
        labels:
          severity: warning
        annotations:
          description: The Kubelet on {{ $labels.node }} has not checked in with the API,
            or has set itself to NotReady, for more than an hour
          summary: Node status is NotReady
      - alert: K8SManyNodesNotReady
        expr: count(kube_node_status_ready{condition="true"} == 0) > 1 and (count(kube_node_status_ready{condition="true"}
          == 0) / count(kube_node_status_ready{condition="true"})) > 0.2
        for: 1m
        labels:
          severity: critical
        annotations:
          description: '{{ $value }} Kubernetes nodes (more than 10% are in the NotReady
            state).'
          summary: Many Kubernetes nodes are Not Ready
      - alert: K8SKubeletDown
        expr: count(up{job="kubelet"} == 0) / count(up{job="kubelet"}) > 0.03
        for: 3m
        labels:
          severity: warning
        annotations:
          description: 'Kubernetes nodes {{ $labels.instance}} scraped failed'
          summary: Kubelets cannot be scraped
      - alert: K8SKubeletDown
        expr: absent(up{job="kubelet"} == 1) or count(up{job="kubelet"} == 0) / count(up{job="kubelet"})
          > 0.1
        for: 3m
        labels:
          severity: critical
        annotations:
          description: Prometheus failed to scrape {{ $value }}% of kubelets, or all Kubelets
            have disappeared from service discovery.
          summary: Many Kubelets cannot be scraped
      - alert: K8SKubeletTooManyPods
        expr: kubelet_running_pod_count > 100
        labels:
          severity: warning
        annotations:
          description: Kubelet {{$labels.instance}} is running {{$value}} pods, close
            to the limit of 110
          summary: Kubelet is close to pod limit
  kubernetes.rules: |
    groups:
    - name: kubernetes
      rules:
      - record: cluster_namespace_controller_pod_container:spec_memory_limit_bytes
        expr: sum(label_replace(container_spec_memory_limit_bytes{container_name!=""},
          "controller", "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace,
          controller, pod_name, container_name)
      - record: cluster_namespace_controller_pod_container:spec_cpu_shares
        expr: sum(label_replace(container_spec_cpu_shares{container_name!=""}, "controller",
          "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace, controller, pod_name,
          container_name)
      - record: cluster_namespace_controller_pod_container:cpu_usage:rate
        expr: sum(label_replace(irate(container_cpu_usage_seconds_total{container_name!=""}[5m]),
          "controller", "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace,
          controller, pod_name, container_name)
      - record: cluster_namespace_controller_pod_container:memory_usage:bytes
        expr: sum(label_replace(container_memory_usage_bytes{container_name!=""}, "controller",
          "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace, controller, pod_name,
          container_name)
      - record: cluster_namespace_controller_pod_container:memory_working_set:bytes
        expr: sum(label_replace(container_memory_working_set_bytes{container_name!=""},
          "controller", "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace,
          controller, pod_name, container_name)
      - record: cluster_namespace_controller_pod_container:memory_rss:bytes
        expr: sum(label_replace(container_memory_rss{container_name!=""}, "controller",
          "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace, controller, pod_name,
          container_name)
      - record: cluster_namespace_controller_pod_container:memory_cache:bytes
        expr: sum(label_replace(container_memory_cache{container_name!=""}, "controller",
          "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace, controller, pod_name,
          container_name)
      - record: cluster_namespace_controller_pod_container:disk_usage:bytes
        expr: sum(label_replace(container_disk_usage_bytes{container_name!=""}, "controller",
          "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace, controller, pod_name,
          container_name)
      - record: cluster_namespace_controller_pod_container:memory_pagefaults:rate
        expr: sum(label_replace(irate(container_memory_failures_total{container_name!=""}[5m]),
          "controller", "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace,
          controller, pod_name, container_name, scope, type)
      - record: cluster_namespace_controller_pod_container:memory_oom:rate
        expr: sum(label_replace(irate(container_memory_failcnt{container_name!=""}[5m]),
          "controller", "$1", "pod_name", "^(.*)-[a-z0-9]+")) BY (cluster, namespace,
          controller, pod_name, container_name, scope, type)
      - record: cluster:memory_allocation:percent
        expr: 100 * sum(container_spec_memory_limit_bytes{pod_name!=""}) BY (cluster)
          / sum(machine_memory_bytes) BY (cluster)
      - record: cluster:memory_used:percent
        expr: 100 * sum(container_memory_usage_bytes{pod_name!=""}) BY (cluster) / sum(machine_memory_bytes)
          BY (cluster)
      - record: cluster:cpu_allocation:percent
        expr: 100 * sum(container_spec_cpu_shares{pod_name!=""}) BY (cluster) / sum(container_spec_cpu_shares{id="/"}
          * ON(cluster, instance) machine_cpu_cores) BY (cluster)
      - record: cluster:node_cpu_use:percent
        expr: 100 * sum(rate(node_cpu{mode!="idle"}[5m])) BY (cluster) / sum(machine_cpu_cores)
          BY (cluster)
      - record: cluster_resource_verb:apiserver_latency:quantile_seconds
        expr: histogram_quantile(0.99, sum(apiserver_request_latencies_bucket) BY (le,
          cluster, job, resource, verb)) / 1e+06
        labels:
          quantile: "0.99"
      - record: cluster_resource_verb:apiserver_latency:quantile_seconds
        expr: histogram_quantile(0.9, sum(apiserver_request_latencies_bucket) BY (le,
          cluster, job, resource, verb)) / 1e+06
        labels:
          quantile: "0.9"
      - record: cluster_resource_verb:apiserver_latency:quantile_seconds
        expr: histogram_quantile(0.5, sum(apiserver_request_latencies_bucket) BY (le,
          cluster, job, resource, verb)) / 1e+06
        labels:
          quantile: "0.5"
      - record: cluster:scheduler_e2e_scheduling_latency:quantile_seconds
        expr: histogram_quantile(0.99, sum(scheduler_e2e_scheduling_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.99"
      - record: cluster:scheduler_e2e_scheduling_latency:quantile_seconds
        expr: histogram_quantile(0.9, sum(scheduler_e2e_scheduling_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.9"
      - record: cluster:scheduler_e2e_scheduling_latency:quantile_seconds
        expr: histogram_quantile(0.5, sum(scheduler_e2e_scheduling_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.5"
      - record: cluster:scheduler_scheduling_algorithm_latency:quantile_seconds
        expr: histogram_quantile(0.99, sum(scheduler_scheduling_algorithm_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.99"
      - record: cluster:scheduler_scheduling_algorithm_latency:quantile_seconds
        expr: histogram_quantile(0.9, sum(scheduler_scheduling_algorithm_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.9"
      - record: cluster:scheduler_scheduling_algorithm_latency:quantile_seconds
        expr: histogram_quantile(0.5, sum(scheduler_scheduling_algorithm_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.5"
      - record: cluster:scheduler_binding_latency:quantile_seconds
        expr: histogram_quantile(0.99, sum(scheduler_binding_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.99"
      - record: cluster:scheduler_binding_latency:quantile_seconds
        expr: histogram_quantile(0.9, sum(scheduler_binding_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.9"
      - record: cluster:scheduler_binding_latency:quantile_seconds
        expr: histogram_quantile(0.5, sum(scheduler_binding_latency_microseconds_bucket)
          BY (le, cluster)) / 1e+06
        labels:
          quantile: "0.5"
  node.rules: |
    groups:
    - name: node
      rules:
      - alert: NodeExporterDown
        expr: absent(up{job="node-exporter"} == 1)
        for: 10m
        labels:
          severity: warning
        annotations:
          description: Prometheus could not scrape a node-exporter for more than 10m,
            or node-exporters have disappeared from discovery.
          summary: node-exporter cannot be scraped
  prometheus.rules: |
    groups:
    - name: prometheus
      rules:
      - alert: FailedReload
        expr: prometheus_config_last_reload_successful == 0
        for: 10m
        labels:
          severity: warning
        annotations:
          description: Reloading Prometheus' configuration has failed for {{ $labels.namespace
            }}/{{ $labels.pod}}.
          summary: Prometheus configuration reload has failed
  mysqld.rules: |
    groups:
    - name: mysqld
      rules:
      - alert: MySQLisDown
        expr: mysql_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          description: 'MySQL Server of {{$labels.instance}} is Down'
          summary: MySQL_is_Down
```



