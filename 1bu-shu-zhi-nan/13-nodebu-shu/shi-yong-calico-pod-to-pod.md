# 在kubernetes集群中部署calico

## Requirements {#requirements}

* kubelet必须配置为CNI \(e.g --network-plugin=cni\).
* kube-proxy 必须运行为iptables模式. 该模式从 Kubernetes v1.2.0.开始为默认模式
* kube-proxy 不能设置 --masquerade-all 参数, 与calico的策略冲突.
*  Kubernetes NetworkPolicy API 需要Kubernetes  v1.3.0以上.
* 当RBAC  启用时, 需要配置正确的role以及serviceaccount.

## [Calico Hosted Install](https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted) {#calico-hosted-install}

kubernetes集群版本&gt;=v1.4时，使用此方法，Calico将运行为DaemonSet。

## [Custom Installation](https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/integration) {#custom-installation}

除了使用kubernetes的DaemonSet方法运行，也可以使用ansible，chef，bash等办法。

（此处不介绍该方法）

