```
[root@ip-10-10-6-201 prometheus-kubernetes]# cat dingtalk.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: dingtalk
  name: dingtalk
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: dingtalk
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: dingtalk
    spec:
      containers:
      - image: 54.223.110.70/kubernetes/dingtalk-webhook:v2.4
        imagePullPolicy: Always
        name: dingtalk
        args:
        - --ding.profile=webhook1=https://oapi.dingtalk.com/robot/send?access_token=xxxx
        ports:
        - containerPort: 8060
          name: dingtalk
          protocol: TCP
        resources:
          limits:
            cpu: 1000m
            memory: 1000Mi
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: dingtalk
    k8s-app: dingtalk
  name: dingtalk
  namespace: monitoring
spec:
  ports:
  - name: dingtalk
    port: 8060
    protocol: TCP
    targetPort: 8060
  selector:
    app: dingtalk
```



