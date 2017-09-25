## NodeAffinity:Node亲和性调度

需要在1.6.x以上的版本才能使用

* RequiredDuringSchedulingIgnoredDuringExecution:必须满足指定的规则才可以调度POD到Node 上;硬限制

* PreferredDuringSchedulingIgnoredDuringExecution:强调优先满足指定规则,调度器会尝试调度Pod到Node上,蛋不强求,多个优先级还能设置权重

```
apiVersion: v1
kind: Pod
metadata:
 name: with-node-affinity
spec:
 affinity:
  nodeAffinity:
   requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: beta.kubernetes.io/arch
        operator: In
        values:
        - amd64
   preferredDuringSchedulingIgnoredDuringExecution:
   - weight: 1
     preference:
      matchExpressions:
      - key: gateway
        operator: In
        values:
        - true
 containers:
 - name: nginx-affinity
   image: nginx
```

* operator:操作符:NodeAffinity语法支持的操作符包括In NotIn,Exists,DoesNoExist,Gt,Lt
* 如果同时定了以nodeSelector和nodeAffinity,那么2个条件必须同时满足,Pod才会调度
* 如果nodeAffinity指定了多个nodeSelectorTerms,那么只需要其中一个能匹配即可
* 如果nodeSelectorTerms中有多个matchExpressions,则一个节点必须满足所有matchExpressions才能运行该pod

## PodAffinity:

* ##### podAffinity:pod亲和性申明
* ##### podAntiAffinity:pod互斥性申明

### 亲和性

如果在具有标签X的Node上运行了一个或者多个符合条件Y的pod,那么pod应该\(如果互斥,则为拒绝运行\)运行在这个Node上,此处的X表示范围,X为一个内置标签,这个key的名字为topologyKey,值如下

* kubernetes.io/hostname
* failure-domain.beta.kubernetes.io/zone
* failure-domain.beta.kubernetes.io/region

```
apiVersion: apps/v1beta1 # for versions before 1.6.0 use extensions/v1beta1
kind: Deployment
metadata:
  name: web-server
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: web-store
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - store
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: web-app
        images: php
```

表示当该Node上有运行标签为app=store的时候,php镜像运行在该node上

### 互斥性:

```
apiVersion: v1
kind: Pod
metadata:
 name: with-node-affinity
spec:
 affinity:
  podAffinity:
   requiredDuringSchedulingIgnoredDuringExecution:
   - labelSelector:
      matchExpressions:
      - key: app
        operator: In
        values:
        - true
     topologyKey: failure-domain.beta.kubernetes.io/zone
  podAntiAffinity:
   requiredDuringSchedulingIgnoredDuringExecution:
   - labelSelector:
     matchExpressions:
     - key: app
       operator: In
       values:
       - nginx
     topologyKey: kubernetes.io/hostname
 containers:
 - name: php-affinity
   image: php
```

* 此要求是这个新的pod必须要调度在app=true这个zone里,但是不能与app=nginx调度到同一台里
* pod的亲和性操作符也包含In NotIn,Exists,DoesNoExist,Gt,Lt
* 在pod亲和性和RequiredDuringScheduling互斥性的定义中,不允许使用空的topologyKey
* 如果在Admission control里定义了包含LimitPodHardAntiAffinityTopology,那么针对RequiredDuringScheduling的Pod互斥性定义就被限制为kubernetes.io/hostname
* 在PreferredDuringScheduling类型的Pod互斥性中,空的topologyKey会被解释为kubernetes.io/hostname,failure-domain.beta.kubernetes.io/zono,failure-domain.beta.kubernetes.io/region的组合
* 


