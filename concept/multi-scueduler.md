# 配置Multiple Schedulers

Kubernetes集群附带了一个默认的Scheduler(详细在这里查看[default-Scheduler](https://kubernetes.io/docs/admin/kube-scheduler/)),如果调度程序不适合你的要求,你可以实现自己的调度程序,不仅如此,你甚至可以在默认的Scheduler之上运行多个Scheduler(并行工作),在集群中指示pod使用哪个Scheduler.

使用如下`yaml`文件部署新的`Scheduler`:

```yaml
admin/sched/my-scheduler.yaml 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-scheduler
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: my-scheduler-as-kube-scheduler
subjects:
- kind: ServiceAccount
  name: my-scheduler
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: system:kube-scheduler
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    component: scheduler
    tier: control-plane
  name: my-scheduler
  namespace: kube-system
spec:
  selector:
    matchLabels:
      component: scheduler
      tier: control-plane
  replicas: 1
  template:
    metadata:
      labels:
        component: scheduler
        tier: control-plane
        version: second
    spec:
      serviceAccountName: my-scheduler
      containers:
      - command:
        - /usr/local/bin/kube-scheduler
        - --address=0.0.0.0
        - --leader-elect=false
        - --scheduler-name=my-scheduler
        image: w564791/kube-scheduler:v1.13.4
        livenessProbe:
          httpGet:
            path: /healthz
            port: 10251
          initialDelaySeconds: 15
        name: kube-second-scheduler
        readinessProbe:
          httpGet:
            path: /healthz
            port: 10251
        resources:
          requests:
            cpu: '0.1'
        securityContext:
          privileged: false
        volumeMounts: []
      hostNetwork: false
      hostPID: false
      volumes: []

```

这里需要注意一些事情,在容器中指定的`schedulerName`在集群中必须是唯一的,这个值在pod中与`spec.schedulerName`字段匹配,用于指定该pod是否需要特定的Scheduler调度

另外我们创建了专用的`service account my-scheduler`与`clusterrole` `system:kube-scheduler`绑定,让其拥有`kube-scheduler`相同的权限.

如果需要将`mutile-scheduler`加入scheduler主节点竞争,需要加入如下参数:

- `--leader-elect=true`  是否参与leader竞争
- `--lock-object-namespace=lock-object-namespace`  默认为`kube-system`
- `--lock-object-name=lock-object-name` 默认为`kube-scheduler`

另外.默认的锁资源为`endpoint`,可以通过`--leader-elect-resource-lock`参数修改为`configMap`(当前支持的锁资源只有`configMap`以及`endpoint`),其它leader竞争有关参数,可以使用--help查询

另外需要修改`clusterrole` `system:kube-scheduler`,为其增加名称为`schedulerName`的资源,完整的`clusterrole`如下:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-scheduler
rules:
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - create
- apiGroups:
  - ""
  resourceNames:
  - my-scheduler
  - kube-scheduler
  resources:
  - endpoints
  verbs:
  - delete
  - get
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - delete
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - bindings
  - pods/binding
  verbs:
  - create
- apiGroups:
  - ""
  resources:
  - pods/status
  verbs:
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - replicationcontrollers
  - services
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  - extensions
  resources:
  - replicasets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  - persistentvolumes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - get
  - list
  - watch

```



在创建pod时,若显示的指定`schedulerName`(默认为`default-scheduler`),该`scheduler`挂掉后,`default-scheduler`也不会对其调度,pod将处于`pending`状态:

```
admin/sched/pod3.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: annotation-second-scheduler
  labels:
    name: multischeduler-example
spec:
  schedulerName: my-scheduler
  containers:
  - name: pod-with-second-annotation-container
    image: k8s.gcr.io/pause:2.0

```

