```
cannot create certificate signing request: certificatesigningrequests.certificates.k8s.io is forbidden:  User "kubelet-bootstrap" cannot create certificatesigningrequests.certificates.k8s.io at the cluster scope
```

用户首次启动时，可能与遇到 kubelet 报 401 无权访问 apiserver 的错误；这是因为在默认情况下，kubelet 通过`bootstrap.kubeconfig`中的预设用户 Token 声明了自己的身份，然后创建 CSR 请求；但是不要忘记这个用户在我们不处理的情况下他没任何权限的，包括创建 CSR 请求；所以需要如下命令创建一个 ClusterRoleBinding，将预设用户`kubelet-bootstrap`

与内置的 ClusterRole`system:node-bootstrapper`绑定到一起，使其能够发起 CSR 请求：

```
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```



