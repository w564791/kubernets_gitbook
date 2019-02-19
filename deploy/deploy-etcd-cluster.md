# 创建高可用 etcd 集群

`kuberntes`系统使用 `etcd`存储所有数据，此处介绍部署一个三节点高可用 `etcd`集群的步骤

etcd version: 3.2.7

使用到的证书:

* ca.pem
* kubernetes-key.pem
* kubernetes.pem

使用yum安装etcd

```
# yum install -y etcd
```

`systemd`启动文件: 三台`etcd`服务的配置都差不多,仅有`--name`部分有所改变,这里只列出一个配置文件\)

```bash
[centos@ip-10-10-6-201 ssl]$ systemctl cat etcd
# /usr/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/bin/etcd \
--name etcd-0 \
--cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
--peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
--trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
--peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
--initial-advertise-peer-urls https://10.10.6.201:2380 \
--listen-peer-urls https://10.10.6.201:2380 \
--listen-client-urls https://10.10.6.201:2379,https://127.0.0.1:2379 \
--advertise-client-urls https://10.10.6.201:2379 \
--initial-cluster-token etcd-cluster-0 \
--initial-cluster etcd-0=https://10.10.6.201:2380,etcd-1=https://10.10.4.12:2380,etcd-2=https://10.10.5.105:2380 \
--initial-cluster-state new \
--data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

* 指定 `etcd`的工作目录为 `/var/lib/etcd`，数据目录为 `/var/lib/etcd`，需在启动服务前创建这两个目录；
* 为了保证通信安全，需要指定 `etcd`的公私钥\(`cert-file`和`key-file`\)、`Peers`通信的公私钥和 `CA`证书\(`peer-cert-file`、`peer-key-file`、`peer-trusted-ca-file`\)、客户端的CA证书（`trusted-ca-file`）；
* 创建`kubernetes.pem`证书时使用的`kubernetes-csr.json`文件的`hosts`字段包含所有`etcd`节点的`IP`，否则证书校验会出错；
* `--initial-cluster-state`值为 `new`时，`--name` 的参数值必须位于 `--initial-cluster` 列表中；
* EnvironmentFile=-/etc/etcd/etcd.conf  可以把参数写在这个配置文件里,更方便管理

启动etcd集群,注意:etcd集群启动时,只有当2个或2个以上启动成功时启动状态返回0,否则启动失败;

## 

## 验证服务

查看集群状态

```
# $ sudo etcdctl --endpoints https://127.0.0.1:2379 --ca-file=/etc/kubernetes/ssl/ca.pem --cert-file=/etc/kubernetes/ssl/kubernetes.pem --key-file=/etc/kubernetes/ssl/kubernetes-key.pem cluster-health
member 3e021ee005d1d0d4 is healthy: got healthy result from https://10.10.5.105:2379
member b10839f801cb056d is healthy: got healthy result from https://10.10.6.201:2379
member ec88b43e6657597d is healthy: got healthy result from https://10.10.4.12:2379
cluster is healthy
```

查看成员列表

```
$ sudo etcdctl --endpoints https://127.0.0.1:2379 --ca-file=/etc/kubernetes/ssl/ca.pem --cert-file=/etc/kubernetes/ssl/kubernetes.pem --key-file=/etc/kubernetes/ssl/kubernetes-key.pem member list
3e021ee005d1d0d4: name=etcd-2 peerURLs=https://10.10.5.105:2380 clientURLs=https://10.10.5.105:2379 isLeader=false
b10839f801cb056d: name=etcd-0 peerURLs=https://10.10.6.201:2380 clientURLs=https://10.10.6.201:2379 isLeader=false
ec88b43e6657597d: name=etcd-1 peerURLs=https://10.10.4.12:2380 clientURLs=https://10.10.4.12:2379 isLeader=true
```

遇到的坑

```
#etcdctl \
--ca-file=/etc/kubernetes/ssl/ca.pem \
--cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
member list
```

```
2017-07-17 17:42:00.878545 I | warning: ignoring ServerName for user-provided CA for backwards compatibility is deprecated
client: etcd cluster is unavailable or misconfigured; error #0: malformed HTTP response "\x15\x03\x01\x00\x02\x02"
; error #1: dial tcp 127.0.0.1:4001: getsockopt: connection refused
```

1. 只需要加上`--endpoints https://127.0.0.1:2379`即可,IP或域名必须是`kubernetes-csr.json`配置文件生成的证书里面已经签名的地址

最后在etcd集群上创建`flanneld`使用的网段:

后文可能使用的配置不一样，只需要稍作修改就好

```
#cat flanneld.json
{
  "Network":"172.16.0.0/16",
  "SubnetLen":24,
  "Backend":{
    "Type":"vxlan",
    "VNI":1
  }
}

# etcdctl \
   --endpoints https://127.0.0.1:2379 \
   --ca-file=/etc/kubernetes/ssl/ca.pem \
   --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
    set /k8s/network/config < flanneld.json
```

查看信息

```
# etcdctl \
   --endpoints https://127.0.0.1:2379 \
   --ca-file=/etc/kubernetes/ssl/ca.pem \
   --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
    get /k8s/network/config
{
"Network":"172.16.0.0/16",
"SubnetLen":24,
"Backend":{
"Type":"vxlan",
"VNI":1
}
}
```

# 使用etcdctl访问kuberentes数据 {#使用etcdctl访问kuberentes数据}

Kubenretes1.6中使用etcd V3版本的API，使用`etcdctl`直接`ls`的话只能看到`/kube-centos`一个路径。需要在命令前加上`ETCDCTL_API=3`这个环境变量才能看到kuberentes在etcd中保存的数据。

```
ETCDCTL_API=3 etcdctl get /registryamespaces/default -w=json|python -m json.tool
ETCDCTL_API=3  etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/ssl/ca.pem --cert=/etc/kubernetes/ssl/kubernetes.pem --key=/etc/kubernetes/ssl/kubernetes-key.pem get/ --prefix   --keys-only
```

* `-w`指定输出格式

key的值是经过base64编码，需要解码后才能看到实际值，如：

```
$ echo L3JlZ2lzdHJ5L25hbWVzcGFjZXMvYXV0b21vZGVs|base64 -d

/registry/namespaces/automodel
```

# etcdctl数据备份与恢复 {#使用etcdctl访问kuberentes数据}

### 对于 API 3 备份与恢复方法

etcd v3恢复时,所有节点都需要恢复snapshot文件,当集群使用`etcdctl snapshot restore`时,会创建新的数据目录,如果未指定`--data-dir` 将在当前目录创建新的数据目录,目录命名方式未`--name`指定的名称与`.etcd`的组合,例如`--name test`此时新的数据目录名称被设定为``test.etcd` ,当不指定`--name`时,新的数据目录被默认命名为`default.etcd`

如下集群数据恢复方法来自官网,未做加密验证,生产使用时,建议加上`https`证书验证:

```
# the following creates new etcd data directories
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m1 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host1:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m2 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host2:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m3 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host3:2380

# Next, start `etcd` with the new data directories:


$ etcd \
  --name m1 \
  --listen-client-urls http://host1:2379 \
  --advertise-client-urls http://host1:2379 \
  --listen-peer-urls http://host1:2380 &
$ etcd \
  --name m2 \
  --listen-client-urls http://host2:2379 \
  --advertise-client-urls http://host2:2379 \
  --listen-peer-urls http://host2:2380 &
$ etcd \
  --name m3 \
  --listen-client-urls http://host3:2379 \
  --advertise-client-urls http://host3:2379 \
  --listen-peer-urls http://host3:2380 &

```



