[Node affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#node-affinity-beta-feature) ,描述的是一组设置在node上的属性,将pod吸附到node上,Taints恰好相反,其让node排斥pod,除非pod带有其指定的属性.

Taints和Tolerations一起工作确保pod不被调度到不适当的node上,一个ndoe上可以设置一个或多个taints,其标记这个node不能接受任何不能容忍taints的pod,当Tolerations被应用于pod时,允许pod被调度到具有匹配污点的节点上.但不做强制要求.

# 概念



