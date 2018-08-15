[Node affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature) ,描述的是一组设置在node上的属性,将pod吸附到node上,Taints恰好相反,其让node排斥pod,除非pod带有其指定的属性.

Taints和Tolerations一起工作确保pod不被调度到不适当的node上,一个ndoe上可以设置一个或多个taints,其标记这个node不能接受任何不能容忍taints的pod,当Tolerations被应用于pod时,允许pod被调度到具有匹配污点的节点上.但不做强制要求.

# 概念

为node添加一个taint属性可以使用 [kubectl taint ](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#taint),例如:

```
$ kubectl taint nodes node1 name=tom:NoSchedule
```

这将在node1上设置key为name,value为tom,effect为NoSchedule 的taint,这意味着pod将不能调度到node1上,除非他具有匹配的toleration

使用如下命令移除该taint

```
$ kubectl taint nodes node1 name:NoSchedule-
```

当设置了taint时,可以在pod中设置toleration,以容忍该taint,如下3种\(精度从上到下依次降低\)tilerations都匹配上面创建的taint,此时该pod将能调度到node1上\(但不是必须\),第三种不建议,此时可能会调度到任何具有effect为NoSchedule的节点上.

```
tolerations:
- key: "name"
  operator: "Equal"
  value: "tom"
  effect: "NoSchedule"
```

```
tolerations:
- key: "name"
  operator: "Exists"
  effect: "NoSchedule"
```

```
tolerations:
- operator: "Exists"
  effect: "NoSchedule"
```

当toleration的key和effects都与taint匹配,并且:

* operator为Exists\(这种情况下不应该指定value\) ,或者

* operator为Equal,此时value相等

operator未指定时默认为Equal

NOTE: 这里有2处需要特别注意:

* 如果key为空并且operator为Equal时将匹配所有key,value和effect将容忍所有

```
tolerations:
- operator: "Exists"
```

* 当effect为空时将匹配所有effects

```
tolerations:
- key: "key"
  operator: "Exists"
```



