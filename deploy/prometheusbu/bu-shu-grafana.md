## 创建grafana-dashboard configmap

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

部署grafana

```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat grafana-*
apiVersion: v1
kind: Secret
metadata:
  name: grafana-credentials
  namespace: monitoring
type: Opaque
data:
  password: cHhzajIwMTc=
  user: cHhzag==
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: grafana
  name: grafana
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: grafana
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - env:
        - name: GF_AUTH_BASIC_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "false"
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              key: user
              name: grafana-credentials
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: grafana-credentials
        image: 54.223.110.70/kubernetes/grafana:4.4.1
        imagePullPolicy: IfNotPresent
        name: grafana
        ports:
        - containerPort: 3000
          name: web
          protocol: TCP
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - mountPath: /var/lib/grafana
          name: grafana-storage
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - hostPath:
          path: /data/grafana
        name: grafana-storage
### create comfigMap grafana-dashboard first
# kubectl create cm grafana-dashboard --from-file=dashboard/
---
apiVersion: batch/v1
kind: Job
metadata:
  name: grafana-import-dashboards
  namespace: monitoring
  labels:
    app: grafana
    component: import-dashboards
spec:
  template:
    metadata:
      name: grafana-import-dashboards
      labels:
        app: grafana
        component: import-dashboards
      annotations:
        pod.beta.kubernetes.io/init-containers: '[
          {
            "name": "wait-for-endpoints",
            "image": "giantswarm/tiny-tools",
            "imagePullPolicy": "IfNotPresent",
            "command": ["fish", "-c", "echo \"waiting for endpoints...\"; while true; set endpoints (curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt --header \"Authorization: Bearer \"(cat /var/run/secrets/kubernetes.io/serviceaccount/token) https://kubernetes.default.svc/api/v1/namespaces/monitoring/endpoints/grafana); echo $endpoints | jq \".\"; if test (echo $endpoints | jq -r \".subsets[]?.addresses // [] | length\") -gt 0; exit 0; end; echo \"waiting...\";sleep 1; end"],
            "args": ["monitoring", "grafana"]
          }
        ]'
    spec:
      serviceAccountName: prometheus-k8s
      containers:
      - name: grafana-import-dashboards
        image: giantswarm/tiny-tools
        command: ["/bin/sh", "-c"]
        workingDir: /opt/grafana-import-dashboards
        args:
          - >
            for file in *-datasource.json ; do
              if [ -e "$file" ] ; then
                echo "importing $file" &&
                curl --silent --fail --show-error \
                  --request POST http://pxsj:pxsj2017@grafana:3000/api/datasources \
                  --header "Content-Type: application/json" \
                  --data-binary "@$file" ;
                echo "" ;
              fi
            done ;
            for file in *-dashboard.json ; do
              if [ -e "$file" ] ; then
                echo "importing $file" &&
                ( echo '{"dashboard":'; \
                  cat "$file"; \
                  echo ',"overwrite":true,"inputs":[{"name":"DS_PROMETHEUS","type":"datasource","pluginId":"prometheus","value":"prometheus"}]}' ) \
                | jq -c '.' \
                | curl --silent --fail --show-error \
                  --request POST http://pxsj:pxsj2017@grafana:3000/api/dashboards/import \
                  --header "Content-Type: application/json" \
                  --data-binary "@-" ;
                echo "" ;
              fi
            done

        volumeMounts:
        - name: config-volume
          mountPath: /opt/grafana-import-dashboards
      restartPolicy: Never
      volumes:
      - name: config-volume
        configMap:
          name: grafana-dashboard
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: grafana
  name: grafana
  namespace: monitoring
spec:
  ports:
  - name: web
    nodePort: 30902
    port: 3000
    protocol: TCP
    targetPort: 3000
  selector:
    app: grafana
  sessionAffinity: None
  type: NodePort
```



