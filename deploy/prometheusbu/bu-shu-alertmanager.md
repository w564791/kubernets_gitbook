```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat alertmanager-main-cm.yaml alertmanager-main-svc.yaml alertmanager-statefulset.yaml
apiVersion: v1
data:
  alertmanager.yaml: |
    global:
      resolve_timeout: 1m
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 2m
      repeat_interval: 30m
      receiver: 'dingtalk'
    receivers:
    - name: 'default'
      email_configs:
      - to: "how_bjl@live.cn"
    - name: 'dingtalk'
      webhook_configs:
      - send_resolved: false
        url: http://dingtalk:8060/dingtalk/webhook1/send
---
kind: ConfigMap
metadata:
  name: alertmanager-main
  namespace: monitoring
apiVersion: v1
kind: Service
metadata:
  labels:
    alertmanager: main
  name: alertmanager-main
  namespace: monitoring
spec:
  ports:
  - name: web
    nodePort: 30903
    port: 9093
    protocol: TCP
    targetPort: web
  selector:
    alertmanager: main
  type: NodePort
---
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  labels:
    alertmanager: main
  name: alertmanager-main
  namespace: monitoring
spec:
  selector:
    matchLabels:
      alertmanager: main
      app: alertmanager
  serviceName: alertmanager-operated
  template:
    metadata:
      labels:
        alertmanager: main
        app: alertmanager
    spec:
      containers:
      - args:
        - -config.file=/etc/alertmanager/config/alertmanager.yaml
        - -web.listen-address=:9093
        - -mesh.listen-address=:6783
        - -storage.path=/etc/alertmanager/data
        - -web.route-prefix=/
        image: 54.223.110.70/kubernetes/alertmanager:v0.7.1
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 10
          httpGet:
            path: /api/v1/status
            port: web
            scheme: HTTP
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 3
        name: alertmanager
        ports:
        - containerPort: 9093
          name: web
          protocol: TCP
        - containerPort: 6783
          name: mesh
          protocol: TCP
        readinessProbe:
          failureThreshold: 10
          httpGet:
            path: /api/v1/status
            port: web
            scheme: HTTP
          initialDelaySeconds: 3
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 3
        resources:
          requests:
            memory: 200Mi
        volumeMounts:
        - mountPath: /etc/alertmanager/config
          name: config-volume
        - mountPath: /var/alertmanager/data
          name: alertmanager-main-db
      - args:
        - -webhook-url=http://localhost:9093/-/reload
        - -volume-dir=/etc/alertmanager/config
        image: 54.223.110.70/kubernetes/configmap-reload:v0.0.1
        imagePullPolicy: IfNotPresent
        name: config-reloader
        resources:
          limits:
            cpu: 5m
            memory: 10Mi
        volumeMounts:
        - mountPath: /etc/alertmanager/config
          name: config-volume
          readOnly: true
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - name: config-volume
        configMap:
          name: alertmanager-main
      - emptyDir:
          sizeLimit: "0"
        name: alertmanager-main-db
  updateStrategy:
    type: OnDelete
```



