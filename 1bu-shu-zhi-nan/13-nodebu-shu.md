# 部署node节点

kubernetes node 节点包含如下组件：

* Flanneld :  v0.9.1
* Docker 17.06.2-ce
* kubelet
* kube-proxy

## 配置Flanneld

```
[root@ip-10-10-6-201 ssl]# systemctl cat flanneld
# /usr/lib/systemd/system/flanneld.service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/flanneld
EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=/usr/bin/flanneld-start $FLANNEL_OPTIONS
ExecStartPost=/usr/libexec/flannel/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=always

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
```

/usr/bin/flanneld-start文件在flanneld下载压缩包里

创建启动脚本并赋予执行权限

```
[root@ip-10-10-6-201 ssl]# cat /usr/bin/flanneld-start
#!/bin/sh

exec /usr/bin/flanneld \
    -etcd-endpoints=${FLANNEL_ETCD_ENDPOINTS:-${FLANNEL_ETCD}} \
    -etcd-prefix=${FLANNEL_ETCD_PREFIX:-${FLANNEL_ETCD_KEY}} \
    "$@"
```

```
# chmoe +x flanneld-start
```

配置文件/etc/sysconfig/flanneld,此文件是强制需求，当然此配置是可以直接配置在systemd的service文件里的，更加方便，推荐那样做。

```
[root@ip-10-10-6-201 ssl]# cat /etc/sysconfig/flanneld
# Flanneld configuration options  

# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD_ENDPOINTS="https://10.10.6.201:2379,https://10.10.4.12:2379,https://10.10.5.105:2379"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_PREFIX="/kubernetes/network"

# Any additional options that you want to pass
FLANNEL_OPTIONS="-etcd-cafile=/etc/kubernetes/ssl/ca.pem -etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem -etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem -healthz-port=10752"
```

启动flanneld

```ini
# systemctl daemon-reload
# systemctl start flanneld
# systemctl enable flanneld
```

* 启动flanneld会生成/run/flannel/docker文件,此文件会被作为docker启动参数,看下这个文件的内容,docker启动时如不引用此文件,可能造成docker0网卡的ip段和flannel0网卡段不一致,很多人都栽在这里
  ```
  DOCKER_OPT_BIP="--bip=10.1.34.1/24"
  DOCKER_OPT_IPMASQ="--ip-masq=true"
  DOCKER_OPT_MTU="--mtu=1472"
  DOCKER_NETWORK_OPTIONS=" --bip=10.1.34.1/24 --ip-masq=true --mtu=1472"
  ```

## 安装配置docker

本例使用的是docker  17.06.2-ce

安装依赖如下:

```
略...
```

使用yum安装

```
yum localinstall -y *rpm
```

修改docker启动文件`/usr/lib/systemd/system/docker.service`

```
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target
Wants=docker-storage-setup.service
Wants=flanneld.service
[Service]
Type=notify
NotifyAccess=all
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
EnvironmentFile=/run/flannel/docker
Environment=GOTRACEBACK=crash
Environment=DOCKER_HTTP_HOST_COMPAT=1
Environment=PATH=/usr/libexec/docker:/usr/bin:/usr/sbin
ExecStart=/usr/bin/dockerd-current \
          --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current \
          --default-runtime=docker-runc \
          --exec-opt native.cgroupdriver=systemd \
          --userland-proxy-path=/usr/libexec/docker/docker-proxy-current \
          $OPTIONS \
          $DOCKER_STORAGE_OPTIONS \
          $DOCKER_NETWORK_OPTIONS \
          $ADD_REGISTRY \
          $BLOCK_REGISTRY \
          $INSECURE_REGISTRY\
          $DOCKER_OPT_BIP\
          $DOCKER_OPT_IPMASQ\
          $DOCKER_OPT_MTU\
          $DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TimeoutStartSec=0
Restart=on-abnormal
MountFlags=slave

[Install]
WantedBy=multi-user.target
```

* `EnvironmentFile=/run/flannel/docker`引用`flanneld`自动生成的docker

* 添加`/run/flannel/docker`内读取到的变量到`docker`启动参数\(`$DOCKER_OPT_BIP  $DOCKER_OPT_IPMASQ    $DOCKER_OPT_MTU   $DOCKER_NETWORK_OPTIONS`\)

启动docker

```
# systemctl daemon-reload
# systemctl start docker
# systemctl enable docker
```

查看虚拟网卡docker0和flannel0在同一网段内

```
# ip a
...
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1472 qdisc noqueue state UP
    link/ether 02:42:72:16:c6:9a brd ff:ff:ff:ff:ff:ff
    inet 10.1.34.1/24 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:72ff:fe16:c69a/64 scope link
       valid_lft forever preferred_lft forever
31: flannel0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1472 qdisc pfifo_fast state UNKNOWN qlen 500
    link/none
    inet 10.1.34.0/16 scope global flannel0
       valid_lft forever preferred_lft forever
...
```

## 安装和配置 kubelet

kubelet 启动时向 kube-apiserver 发送 TLS bootstrapping 请求，需要先将 bootstrap token 文件中的 kubelet-bootstrap 用户赋予 system:node-bootstrapper cluster 角色\(role\)，  
然后 kubelet 才能有权限创建认证请求\(certificate signing requests\)：

```bash
$ cd /etc/kubernetes
$ kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```

* `--user=kubelet-bootstrap` 是在 `/etc/kubernetes/token.csv` 文件中指定的用户名，同时也写入了 `/etc/kubernetes/bootstrap.kubeconfig` 文件；

### 创建 kubelet 的service配置文件

* ##### kubelet 依赖docker服务,需要先启动docker
* ##### kubelet 启动之前工作目录必须创建,否则会报错,如下:

          `/usr/local/kubernetes/server/bin/kubele :No such file or ...`

`kubelet`启动文件`/usr/lib/systemd/system/kubelet.service`

```
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
[Service]
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/local/kubernetes/server/bin/kubelet \
$KUBE_LOGTOSTDERR \
$KUBE_LOG_LEVEL \
$KUBELET_API_SERVER \
$KUBELET_ADDRESS \
$KUBELET_PORT \
$KUBELET_HOSTNAME \
$KUBE_ALLOW_PRIV \
$KUBELET_POD_INFRA_CONTAINER \
$KUBELET_ARGS
Restart=on-failure
[Install]
WantedBy=multi-user.target
```

创建kubelet和kube-proxy公配置文件:`/etc/kubernetes/config`

```ini
KUBE_MASTER="--master=https://k8s-1"
KUBE_LOGTOSTDERR="--logtostderr=false"
KUBE_LOG_LEVEL="--v=0"
```

创建kubelet配置文件`/etc/kubernetes/kubelet`

```
KUBELET_ADDRESS="--address=192.168.103.143"
KUBELET_HOSTNAME="--hostname-override=k8s-1"
KUBELET_API_SERVER="--api-servers=https://k8s-1"
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"
KUBELET_ARGS="--cluster-dns=10.254.0.2 --cgroup-driver=systemd --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --require-kubeconfig --cert-dir=/etc/kubernetes/ssl --cluster-domain=cluster.local. --hairpin-mode promiscuous-bridge --serialize-image-pulls=false --log-dir=/var/log/k8s  --register-node=true"
```

* `--address` 不能设置为 `127.0.0.1`，否则后续 Pods 访问 kubelet 的 API 接口时会失败，因为 Pods 访问的 `127.0.0.1` 指向自己而不是 kubelet；
* 如果设置了 `--hostname-override` 选项，则 `kube-proxy` 也需要设置该选项，否则会出现找不到 Node 的情况；
* `--experimental-bootstrap-kubeconfig` 指向 bootstrap kubeconfig 文件，kubelet 使用该文件中的用户名和 token 向 kube-apiserver 发送 TLS Bootstrapping 请求；
* 管理员通过了 CSR 请求后，kubelet 自动在 `--cert-dir` 目录创建证书和私钥文件\(`kubelet-client.crt` 和 `kubelet-client.key`\)，然后写入 `--kubeconfig` 文件；
* 建议在 `--kubeconfig` 配置文件中指定 `kube-apiserver` 地址，如果未指定 `--api-servers` 选项，则必须指定 `--require-kubeconfig` 选项后才从配置文件中读取 kube-apiserver 的地址，否则 kubelet 启动后将找不到 kube-apiserver \(日志中提示未找到 API Server），`kubectl get nodes` 不会返回对应的 Node 信息;
* `--cluster-dns` 指定 kubedns 的 Service IP\(可以先分配，后续创建 kube-dns 服务时指定该 IP,这里暂时先不加,否则会启动失败\)，`--cluster-domain` 指定域名后缀，这两个参数同时指定后才会生效；
* `--kubeconfig=/etc/kubernetes/kubelet.kubeconfig`中指定的`kubelet.kubeconfig`文件在第一次启动kubelet之前并不存在，请看下文，当通过CSR请求后会自动生成`kubelet.kubeconfig`文件，如果你的节点上已经生成了`~/.kube/config`文件，你可以将该文件拷贝到该路径下，并重命名为`kubelet.kubeconfig`，所有node节点可以共用同一个kubelet.kubeconfig文件，这样新添加的节点就不需要再创建CSR请求就能自动添加到kubernetes集群中。同样，在任意能够访问到kubernetes集群的主机上使用`kubectl —kubeconfig`命令操作集群时，只要使用`~/.kube/config`文件就可以通过权限认证，因为这里面已经有认证信息并认为你是admin用户，对集群拥有所有权限。
* --pod-infra-container-image 指定POD运行时的基础镜像,建议先下载下来
* --node-status-update-frequency 设置kublet每隔多久向apiserver报告状态,默认是10s

### 启动kublet

```bash
# systemctl daemon-reload
# systemctl enable kubelet
# systemctl start kubelet
```

### 通过 kublet 的 TLS 证书请求

kubelet 首次启动时向 kube-apiserver 发送证书签名请求，必须通过后 kubernetes 系统才会将该 Node 加入到集群。

查看未授权的 CSR 请求

```bash
# kubectl  get csr
NAME        AGE       REQUESTOR           CONDITION
csr-37cll   6d        kubelet-bootstrap   Pending
```

通过 CSR 请求

```bash
# kubectl certificate approve csr-37cll
certificatesigningrequest "csr-37cll" approved
# kubectl get no
NAME      STATUS     AGE       VERSION
k8s-1     Ready      1d        v1.6.6
```

自动生成了 kubelet kubeconfig 文件和公私钥

```
# ls -l /etc/kubernetes/kubelet.kubeconfig  /etc/kubernetes/ssl/kubelet*
-rw-------  1 root root 2267 Jul 16 18:19 /etc/kubernetes/kubelet.kubeconfig
-rw-r--r--  1 root root 1038 Jul 12 13:14 /etc/kubernetes/ssl/kubelet-client.crt
-rw-------. 1 root root  227 Jul 11 16:16 /etc/kubernetes/ssl/kubelet-client.key
-rw-r--r--  1 root root 1094 Jul 12 13:14 /etc/kubernetes/ssl/kubelet.crt
-rw-------  1 root root 1679 Jul 12 13:14 /etc/kubernetes/ssl/kubelet.key
```

* 假如你更新`kubernetes`的证书，只要没有更新`token.csv`，当重启kubelet后，该node就会自动加入到kuberentes集群中，而不会重新发送`certificaterequest`，也不需要在`master`节点上执行`kubectl certificate approve`操作。前提是不要删除node节点上的`/etc/kubernetes/ssl/kubelet*`和`/etc/kubernetes/kubelet.kubeconfig`文件。否则`kubelet`启动时会提示找不到证书而失败。

## 配置 kube-proxy

**创建 kube-proxy 的service配置文件**

文件路径`/usr/lib/systemd/system/kube-proxy.service`

```bash
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/usr/local/kubernetes/server/bin/kube-proxy \
$KUBE_LOGTOSTDERR \
$KUBE_LOG_LEVEL \
$KUBE_MASTER \
$KUBE_PROXY_ARGS
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

创建kube-proxy配置文件`/etc/kubernetes/proxy`

```
KUBE_PROXY_ARGS="--bind-address=192.168.103.143 --hostname-override=k8s-1 --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig --log-dir=/var/log/k8s --logtostderr=false --v=0 --cluster-cidr=10.254.0.0/16"
```

* `--hostname-override` 参数值必须与 kubelet 的值一致，否则 kube-proxy 启动后会找不到该 Node，从而不会创建任何 iptables 规则；
* kube-proxy 根据 `--cluster-cidr` 判断集群内部和外部流量，指定 `--cluster-cidr` 或 `--masquerade-all` 选项后 kube-proxy 才会对访问 Service IP 的请求做 SNAT；
* `--kubeconfig` 指定的配置文件嵌入了 kube-apiserver 的地址、用户名、证书、秘钥等请求和认证信息；
* 预定义的 RoleBinding `cluster-admin` 将User `system:kube-proxy` 与 Role `system:node-proxier` 绑定，该 Role 授予了调用 `kube-apiserver` Proxy 相关 API 的权限；

### 启动 kube-proxy

```
# systemctl daemon-reload
# systemctl enable kube-proxy
# systemctl start kube-proxy
```

## 验证测试:

创建一个nginx的service:

```bash
# cat nginx-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: kube-system
  labels:
    name: nginx-service-local
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    name: nginx
```

创建一个副本为1的nginx的RC

```bash
# cat nginx.yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-rc
  namespace: kube-system
spec:
  replicas: 1
  selector:
    name: nginx
  template:
    metadata:
      labels:
        name: nginx
    spec:
      containers:
        - name: nginx
          image: docker.io/nginx:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
            - containerPort: 443
```

查看SVC地址:

```bash
# kubectl get svc -n kube-system nginx-service
NAME            CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx-service   10.254.51.237   <none>        80/TCP    2d
```

[ http命令下载](https://github.com/jakubroztocil/httpie#linux) 或者使用yum安装

```
yum install httpie -y
```

使用http命令get svc地址:

```
# http 10.254.51.237
HTTP/1.1 200 OK
Accept-Ranges: bytes
Connection: keep-alive
Content-Length: 612
Content-Type: text/html
Date: Tue, 18 Jul 2017 07:46:41 GMT
ETag: "5964cd3f-264"
Last-Modified: Tue, 11 Jul 2017 13:06:07 GMT
Server: nginx/1.13.3

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```



