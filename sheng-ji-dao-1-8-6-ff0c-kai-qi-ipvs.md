## 升级注意事项（测试中发现nodePort不能用）

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

#### 6.修改iptables FORWARD链默认规则

```
iptables -P FORWARD ACCEPT
```

# 升级步骤

### master升级

1. 替换kube-apiserver二进制文件，并重启
2. 替换kube-controller-manager，kube-scheduler二进制文件，并重启

### node升级

1. 替换kubelet ,kube-proxy二进制文件，并重启

#### 查看ipvs规则

```
root@node3:/var/lib/k8s# ipvsadm -ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr persistent 10800
  -> 192.168.70.175:443           Masq    1      3          0         
TCP  10.254.0.2:53 rr
  -> 172.16.30.5:53               Masq    1      0          0         
TCP  10.254.0.2:10054 rr
  -> 172.16.30.5:10054            Masq    1      0          0         
TCP  10.254.2.133:80 rr
  -> 172.16.30.6:8082             Masq    1      0          0         
TCP  10.254.9.181:8060 rr
  -> 172.16.30.9:8060             Masq    1      0          0         
TCP  10.254.11.74:9189 rr
  -> 172.16.30.8:9189             Masq    1      0          0         
TCP  10.254.61.226:1 rr
  -> 192.168.70.170:1             Masq    1      0          0         
  -> 192.168.70.171:1             Masq    1      0          0         
  -> 192.168.70.175:1             Masq    1      0          0         
TCP  10.254.108.248:8083 rr
  -> 172.16.30.7:8083             Masq    1      0          0         
TCP  10.254.108.248:8086 rr
  -> 172.16.30.7:8086             Masq    1      1          0         
TCP  10.254.112.16:8080 rr
  -> 172.16.30.11:8080            Masq    1      1          0         
TCP  10.254.142.157:9093 rr
  -> 172.16.60.2:9093             Masq    1      0          0         
TCP  10.254.163.130:3000 rr
  -> 172.16.30.3:3000             Masq    1      0          0         
TCP  10.254.178.246:8080 rr
  -> 172.16.30.2:8080             Masq    1      0          0         
TCP  10.254.191.69:1 rr
  -> 192.168.70.170:1             Masq    1      0          0         
  -> 192.168.70.171:1             Masq    1      0          0         
  -> 192.168.70.175:1             Masq    1      0          0         
TCP  10.254.206.231:9090 rr
  -> 172.16.29.2:9090             Masq    1      0          0         
TCP  10.254.221.230:443 rr
  -> 172.16.30.4:8443             Masq    1      0          0         
UDP  10.254.0.2:53 rr
  -> 172.16.30.5:53               Masq    1      0          0
```

#### 查看网卡信息

```
5: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default 
    link/ether 9a:e8:d9:d8:7b:cc brd ff:ff:ff:ff:ff:ff
    inet 10.254.112.16/32 brd 10.254.112.16 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.9.181/32 brd 10.254.9.181 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.0.2/32 brd 10.254.0.2 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.178.246/32 brd 10.254.178.246 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.11.74/32 brd 10.254.11.74 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.221.230/32 brd 10.254.221.230 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.108.248/32 brd 10.254.108.248 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.206.231/32 brd 10.254.206.231 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.191.69/32 brd 10.254.191.69 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.142.157/32 brd 10.254.142.157 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.163.130/32 brd 10.254.163.130 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.2.133/32 brd 10.254.2.133 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.0.1/32 brd 10.254.0.1 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
    inet 10.254.61.226/32 brd 10.254.61.226 scope global kube-ipvs0
       valid_lft forever preferred_lft forever
```



