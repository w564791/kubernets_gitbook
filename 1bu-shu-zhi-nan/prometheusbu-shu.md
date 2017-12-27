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

Prometheus-rules

Prometheus-discover

Prometheus-etcd监控

Prometheus-kubelet监控

