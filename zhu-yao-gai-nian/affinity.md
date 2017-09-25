## NodeAffinity:Node亲和性调度

需要在1.6.x以上的版本才能使用

RequiredDuringSchedulingIgnoredDuringExecution:必须满足指定的规则才可以调度POD到Node 上;硬限制

PreferredDuringSchedulingIgnoredDuringExecution:强调优先满足指定规则,调度器会尝试调度Pod到Node上,蛋不强求,多个优先级还能设置权重

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

如果在具有标签X的Node上运行了一个或者多个符合条件Y的pod,那么pod应该\(如果互斥,则为拒绝运行\)运行在这个Node上,此处的X表示范围,X为一个内置标签,这个key的名字为topologyKey,值如下

* kubernetes.io/hostname
* failure-domain.beta.kubernetes.io/zone
* failure-domain.beta.kubernetes.io/region

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
        - nginx
     topologyKey: kubernetes.io/hostname 
 containers:
 - name: php-affinity
   image: php
```

表示当该Node上有运行标签为app=nginx的时候,php镜像运行在该node上

