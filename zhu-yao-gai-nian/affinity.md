## NodeAffinity:Node亲和性

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

## PodAffinity: Pod亲和性

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
        image: php
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

## Taints和Tolerations

NodeAffinity是在Pod上定义的一种属性,使得Pod能调度到某些Node上运行,Taints恰好相反,它拒绝Pod运行

Taints需要和Tolerations配合使用,让Pod避开那些不适合的Node,在Node上设置一个或多个Taints过后没出费Pod明确声明能容忍这些污点,否则无法在这些Node上运行

Toleration是Pod的属性,让pod能够\(只是能够,不是必须\)运行在标注了Taint的Node上

kubectl taint命令为Node设置Taint信息

```
kubectl taint nodes node1 key=value:NoSchedule
```

这个设置为node1加上一个Taint,该Taint的键为key,值为value,效果是NoSchedule,这意味着pod除非明确声明可以容忍这个Taint,否则就不会调度到node1上去,然后需要在pod上声明Toleration

```
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
或者
tolerations:
- key: "key"
  operator: "Exists"
  effect: "NoSchedule"
```

Pod的Toleration声明中的key和effect需要和Taint的设置保持一致,并且满足以下条件之一:

* operator的值是Exists\(无须指定value\)
* operator的值是Equal并且value值相等
* 如果不指定operator,默认值是Equal

关于effect取值

* NoSchedule 
* PreferNoSchedule,这个值的意思是优先,也可以算NoSchedule的软限制版本,一个Pod如果没有声明容忍这个Taint,那么系统会尽量避免把这个Pod调度到这个节点上去,但不是强制的
* NoExecute:如果给Node加上effect=NoExecute的Taint,那么该Node上正在运行的所有无对应Toleration的Pod都会被立刻驱逐,具有相应Toleration的Pod则永远不会被驱逐,系统允许给具有NoExecute效果的Toleration加入相应的tolerationSeconds字段,表明Pod可以在taint添加到Node后还能再这个Node上运行多久\(单位为s\)

如下设置Node的Taint

```
kubectl taint nodes node1 key1=value1:NoSchedule
kubectl taint nodes node1 key1=value1:NoExecute
kubectl taint nodes node1 key2=value2:NoSchedule
```

在pod上定义Tolerations:

```
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute
```

这样的结果是改pod无法被调度到node1上去,因为第三个Taint没有匹配Toleration,但是如果该pod已经在node1上运行,那么在运行时设置上第三个Taint,他还能继续在Node上运行,这是因为Pod可以容忍前2个Taint.

```
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoExecute
  tolerationSeconds: 3600
```

上述定义的意思是,如果pod正在运行,所在节点被加入一个匹配的Taint,则这个Pod会持续在这个节点上存活3600秒,然后被驱逐,如果在这个宽限期内,Taint被移除,那么不会触发驱逐事件

