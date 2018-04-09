# 在kubernetes集群中部署calico

## Requirements {#requirements}

* kubelet必须配置为CNI \(e.g --network-plugin=cni\).
* kube-proxy 必须运行为iptables模式. 该模式从 Kubernetes v1.2.0.开始为默认模式
* The kube-proxy must be started without the --masquerade-all flag, which conflicts with Calico policy.
* The Kubernetes NetworkPolicy API requires at least Kubernetes version v1.3.0.
* When RBAC is enabled, the proper accounts, roles, and bindings must be defined and utilized by the Calico components. Examples exist for both the etcd and kubernetes api datastores.



