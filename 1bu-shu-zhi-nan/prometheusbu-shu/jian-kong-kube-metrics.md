```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat kube-state-metrics-svc.yaml kube-state-metrics-rbac.yaml kube-state-metrics-deploy.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: kube-state-metrics
    k8s-app: kube-state-metrics
  name: kube-state-metrics
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - name: http-metrics
    port: 8080
    protocol: TCP
    targetPort: metrics
    nodePort: 30904
  selector:
    app: kube-state-metrics
  sessionAffinity: None
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - pods
  - services
  - resourcequotas
  - replicationcontrollers
  - limitranges
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - ""
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: monitoring
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: monitoring
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: kube-state-metrics
  name: kube-state-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: kube-state-metrics
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      containers:
      - image: 54.223.110.70/kubernetes/kube-state-metrics:v0.5.0
        imagePullPolicy: IfNotPresent
        name: kube-state-metrics
        ports:
        - containerPort: 8080
          name: metrics
          protocol: TCP
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      serviceAccount: kube-state-metrics
      serviceAccountName: kube-state-metrics

```



