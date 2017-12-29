## 升级注意事项

#### 1.调整内核参数

```
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
```

#### 2.加载内核模块

```
root@node2:/var/lib/k8s# cat /etc/modules
# /etc/modules: kernel modules to load at boot time.
#
# This file contains the names of kernel modules that should be loaded
# at boot time, one per line. Lines beginning with "#" are ignored.
ip_vs 
ip_vs_lc 
ip_vs_wlc 
ip_vs_rr 
ip_vs_wrr 
ip_vs_lblc 
ip_vs_lblcr 
ip_vs_dh 
ip_vs_sh 
ip_vs_fo 
ip_vs_nq 
ip_vs_sed 
ip_vs_ftp 
nf_conntrack_ipv4
dm_snapshot
dm_mirror
dm_thin_pool
```

#### 3.关闭swap

```
临时关闭
# swapoff -a
永久关闭
# sed -i '/swap/d' /etc/fstab
```

未关闭时报错如下：

```
error: failed to run Kubelet: Running with swap on is not supported, please disable swap! or set --fail-swap-on flag to false. /proc/swaps
```

#### 4.修改kube-proxy参数

因为ipvs还是alpha版本，所以需要开启`--feature-gates`，并且需要打开`--masquerade-all`选项，确保反向流量通过。

```
--feature-gates SupportIPVSProxyMode=true --masquerade-all
```

#### 5.安装ipvsadm

```
#apt install ipvsadm
```

# 升级步骤

### master升级

1. 替换kube-apiserver二进制文件，并重启
2. 替换kube-controller-manager，kube-scheduler二进制文件，并重启

### node升级

1. 替换kubelet ,kube-proxy二进制文件，并重启



