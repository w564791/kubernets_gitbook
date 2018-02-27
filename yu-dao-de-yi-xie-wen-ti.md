1.8版本之前.开启rbac后,apiserver默认绑定system:nodes组到system:node的clusterrole。v1.8之后,此绑定默认不存在,需要手工绑定,否则kubelet启动后会报认证错误，使用kubectl get nodes查看无法成为Ready状态。

### 默认角色与默认角色绑定

API Server会创建一组默认的 ClusterRole和 ClusterRoleBinding对象。 这些默认对象中有许多包含 system:前缀，表明这些资源由Kubernetes基础组件”拥有”。 对这些资源的修改可能导致非功能性集群（non-functional cluster） 。一个例子是 system:node ClusterRole对象。这个角色定义了kubelets的权限。如果这个角色被修改，可能会导致kubelets无法正常工作。

所有默认的ClusterRole和ClusterRoleBinding对象都会被标记为kubernetes.io/bootstrapping=rbac-defaults。

使用命令kubectl get clusterrolebinding和kubectl get clusterrole可以查看系统中的角色与角色绑定 



使用命令kubectl get clusterrolebindings system:node -o yaml或kubectl describe clusterrolebindings system:node查看system:node角色绑定的详细信息：

```
root@master:~# kubectl describe clusterrolebindings system:node  
Name:         system:node  
Labels:       kubernetes.io/bootstrapping=rbac-defaults  
Annotations:  rbac.authorization.kubernetes.io/autoupdate=true  
Role:  
  Kind:  ClusterRole  
  Name:  system:node  
Subjects:  
  Kind  Name  Namespace  
  ----  ----  --------- 
```



