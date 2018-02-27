```
Unable to register node "192.168.70.175" with API server: nodes is forbidden: User "system:node:192.168.70.175" cannot create nodes at the cluster scope
Failed to list *v1.Node: nodes is forbidden: User "system:node:192.168.70.175" cannot list nodes at the cluster scope
Failed to list *v1.Service: services is forbidden: User "system:node:192.168.70.175" cannot list services at the cluster scope
Failed to list *v1.Pod: pods is forbidden: User "system:node:192.168.70.175" cannot list pods at the cluster scope
Failed to list *v1.Node: nodes is forbidden: User "system:node:192.168.70.175" cannot list nodes at the cluster scope
Failed to list *v1.Service: services is forbidden: User "system:node:192.168.70.175" cannot list services at the cluster scope
Failed to list *v1.Pod: pods is forbidden: User "system:node:192.168.70.175" cannot list pods at the cluster scope
```

[上文](/1bu-shu-zhi-nan/kubernetes-tsl-bootstrapping.md)提到:

* nodeclient: kubelet 以`O=system:nodes`和`CN=system:node:(node name)`形式发起的 CSR 请求

此时发起请求的用户为system:node:192.168.70.175，为避免多次授权，此处直接授权给`system:nodes`组

```
kubectl create clusterrolebinding kubelet-nodegroup-clusterbinding --clusterrole=system:node --group=system:nodes
```



