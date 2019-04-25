# 部署高可用 kubernetes master 集群

kubernetes master 节点包含的组件：

* kube-apiserver
* kube-scheduler
* kube-controller-manager

目前这三个组件需要部署在同一台机器上。

* `kube-scheduler`、`kube-controller-manager`和`kube-apiserver`三者的功能紧密相关；同时只能有一个`kube-scheduler，kube-controller-manager`
* `kube-scheduler`、`kube-controller-manager`进程处于工作状态，如果运行多个，则需要通过选举产生一个 leader；

此处记录部署一个三个节点的高可用 kubernetes master 集群步骤,后续创建一个`load balancer`\(以前我用的nginx4层代理，此处我使用的是aws的classic LB，但是nginx的配置保留\)来代理访问`kube-apiserver` 的请求

[下载相应版本的二进制包](https://github.com/kubernetes/kubernetes/releases)

此处使用的是v1.10.2版本

```
root@node1:~# tree /opt/kubernetes/
/opt/kubernetes/
├── addons
├── client
│   └── bin
│       ├── kubectl
│       └── kubefed
├── kubernetes-src.tar.gz
├── LICENSES
├── node
│   └── bin
│       ├── kubectl
│       ├── kubefed
│       ├── kubelet
│       └── kube-proxy
└── server
    └── bin
        ├── apiextensions-apiserver
        ├── cloud-controller-manager
        ├── cloud-controller-manager.docker_tag
        ├── cloud-controller-manager.tar
        ├── hyperkube
        ├── kubeadm
        ├── kube-aggregator
        ├── kube-aggregator.docker_tag
        ├── kube-aggregator.tar
        ├── kube-apiserver
        ├── kube-apiserver.docker_tag
        ├── kube-apiserver.tar
        ├── kube-controller-manager
        ├── kube-controller-manager.docker_tag
        ├── kube-controller-manager.tar
        ├── kubectl
        ├── kubefed
        ├── kubelet
        ├── kube-proxy
        ├── kube-proxy.docker_tag
        ├── kube-proxy.tar
        ├── kube-scheduler
        ├── kube-scheduler.docker_tag
        └── kube-scheduler.tar
```

设置环境变量\(略\);

再次确认下证书:

```
# # ls /etc/kubernetes/ssl/ /etc/kubernetes/token.csv
/etc/kubernetes/token.csv

/etc/kubernetes/ssl/:
admin-key.pem  bootstrap.kubeconfig  ca.pem              kube-proxy.pem      kubernetes.pem
admin.pem      ca-key.pem            kube-proxy-key.pem  kubernetes-key.pem
```

## 准备kubeconfig文件

* --master在kubernetes1.8X以后弃用，此处使用kubeconfig文件代替,具体配置方法如[创建kubeconfig文件章节](make-kubeconfig-file.md)

```
[root@ip-10-10-6-201 ssl]# cat /etc/kubernetes/kubeconfig 
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/ssl/ca.pem
    server: https://192.168.178.128:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: admin
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate: /etc/kubernetes/ssl/admin.pem
    client-key: /etc/kubernetes/ssl/admin-key.pem
```

## 配置和启动 kube-apiserver

**创建 kube-apiserver的service配置文件**

api-server `serivce`配置文件内容：

```bash
# cat /lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service
[Service]
ExecStart=/bin/kube-apiserver \
--logtostderr=false --log-dir=/var/log/k8s -v=0 --allow-privileged=true \
--bind-address=192.168.178.128 --secure-port=6443 --insecure-bind-address=0.0.0.0 --insecure-port=8080 \
--etcd-servers=https://192.168.178.128:2379 \
--service-cluster-ip-range=10.254.0.0/16 --kubelet-https=true --service-node-port-range=79-60000  \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction,PodSecurityPolicy \
--authorization-mode=Node,RBAC \
--enable-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv \
--enable-garbage-collector \
--enable-logs-handler \
--tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
--client-ca-file=/etc/kubernetes/ssl/ca.pem \
--kubelet-client-certificate=/etc/kubernetes/ssl/kubernetes.pem \
--kubelet-client-key=/etc/kubernetes/ssl/kubernetes-key.pem \
--service-account-key-file=/etc/kubernetes/ssl/sa.pub \
--requestheader-client-ca-file=/etc/kubernetes/ssl/ca.pem \
--proxy-client-cert-file=/etc/kubernetes/ssl/kube-proxy.pem \
--proxy-client-key-file=/etc/kubernetes/ssl/kube-proxy-key.pem \
--requestheader-extra-headers-prefix=X-Remote-Extra- \
--requestheader-group-headers=X-Remote-Group \
--requestheader-username-headers=X-Remote-User \
#--enable-aggregator-routing=true \
#--requestheader-allowed-names=metrics-server,admin,system:kube-proxy \
--requestheader-allowed-names=system:kube-proxy \
--etcd-cafile=/etc/kubernetes/ssl/ca.pem \
--etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \
--etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \
--apiserver-count=1  \
--storage-backend=etcd3 \
--audit-policy-file=/etc/kubernetes/audit.yaml --audit-log-path=/var/log/audit \
--audit-log-maxage=1 --audit-log-maxbackup=1 --audit-log-maxsize=1024 --enable-swagger-ui=false
Restart=always
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target

```

* --logtostderr=false 是否将日志输出到标准输出,这里选择false,输出到 `--log-dir=/var/lib/k8s`目录
* `--v=0` 设置日志等级
* `--advertise-address` :该地址为`apiserver`集群广播地址,此地址必须能为集群其他部分访问到,如果为空,则使用`--bind-address`，如果`--bind-address`未被制定,那么将使用主机的默认地址；
* `--etcd-servers :`指定etcd集群地址,这里使用https;
* `--admission-control`,必须包含`ServiceAccount`;
* `--authorization-mode=RBAC` 指定在安全端口使用 RBAC 授权模式，拒绝未通过授权的请求;
* `kubelet、kube-proxy、kubectl`部署在其它 `Node`节点上，如果通过**安全端口**访问`kube-apiserver`，则必须先通过 TLS 证书认证，再通过 RBAC 授权
* `--runtime-config`配置为`rbac.authorization.k8s.io/v1beta1`，表示运行时的apiVersion；
* `--service-cluster-ip-range` 指定 Service Cluster IP 地址段，该地址段不能路由可达;
* `--apiserver-count=3`设置集群中master数量
* `--service-node-port-rang`指定`svc`打开的端口范围
* `--service-account-key-file`PEM 编码的 X509 RSA 或者 ECDSA 的私钥或者公钥，用于检验 ServiceAccount 的 token。如果没指定的话，会使用`--tls-private-key-file`替代。文件中可以包含多个 Key，这一参数可以重复指定多个文件。
* 本例指定了`PodSecurityPolicy`资源,如不定义`psp`资源,将无法使用某些功能
* 此处有`PodSecurityPolicy`示例,该示例定义了3个`psp`资源, `privileged,restricted,need-root`,创建后calico插件可以正常运行,[到此获取yaml](../yaml/podsecuripolycies-basic.yaml)

启动`kube-apiserver`

```
# systemctl daemon-reload
```

```bash
# systemctl enable kube-apiserver
# systemctl start kube-apiserver
```

## 配置和启动 kube-controller-manager

### 创建 kube-controller-manager kubeconfig 文件

```bash
# 设置集群参数
# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig
# 设置客户端认证参数
# kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/etc/kubernetes/ssl/kube-controller-manager.pem \
  --client-key=/etc/kubernetes/ssl/kube-controller-manager.pem \
  --embed-certs=false \
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig
# 设置上下文参数
# kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig
# 设置默认上下文
# kubectl config use-context default --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig
```

- 

**创建 kube-controller-manager的serivce配置文件**

```bash
# cat /lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/controller-manager
ExecStart=/bin/kube-controller-manager \
--experimental-cluster-signing-duration 175200h0m0s --bind-address=127.0.0.1 \
--cluster-name=kubernetes --service-cluster-ip-range=10.254.0.0/16 \
--kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
--authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
--authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
--allocate-node-cidrs=true \
--cluster-cidr=172.20.0.0/16 \
--cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
--cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
--service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem \
--root-ca-file=/etc/kubernetes/ssl/ca.pem \
--leader-elect=true \
--logtostderr=false --log-dir=/var/log/k8s -v=0  \
--feature-gates=RotateKubeletServerCertificate=true \
--terminated-pod-gc-threshold=100 \
--service-account-private-key-file=/etc/kubernetes/ssl/sa.key \
--use-service-account-credentials=true
Restart=on-failure --service-cluster-ip-range=79-65535

LimitNOFILE=65536
[Install]
WantedBy=multi-user.target

```

* `--service-cluster-ip-range` 参数指定 `Cluster`中 `Service`的CIDR范围，该网络在各 Node 间必须路由不可达，必须和 `kube-apiserver` 中的参数一致;
* `--leader-elect=true` leader选举
* `--address` 值必须为 `127.0.0.1`，因为当前`kube-apiserver` 期望 `scheduler`和 `controller-manager`在同一台机器;否则会报错
* `--root-ca-file` 用来对 kube-apiserver 证书进行校验，**指定该参数后，才会在Pod 容器的 ServiceAccount 中放置该 CA 证书文件;**
* `--experimental-cluster-signing-duration` 设置签署的证书有效时间，默认为1年
* `--service-account-private-key-file`PEM 编码的 X509 RSA 或者 ECDSA Key，用于签署 Service Account Token。Controller Manager 使用私钥签署 Service Account Token。跟 Kubernetes 中使用的其他私钥不同的是，这个私钥是不支持同一 CA 验证的，因此上，需要给每个 Controller Manager 指定一致的私钥文件。这个 Key 也不需要什么 CA 来做签署，生成很容易：

```
openssl genrsa -out sa.key 4096
openssl rsa -in sa.key -pubout >sa.pub
```

然后分发给每个 Controller Manager 和 API Server 就可以了。使用和 `--tls-private-key-file` 一致的文件是可以工作的——只要你给每个 API Server 用的都是同一个 TLS Key（一般都这么做的吧？）。（这里我假设你运行的一个有高可用支持的，多个 API Server 和多个 Controller Manager同时运行的集群）(本条解释来自[Kubernetes 的证书认证](https://blog.fleeto.us/post/certs-in-kubernetes/)

### 启动 kube-controller-manager

```
# systemctl daemon-reload
# systemctl enable kube-controller-manager
# systemctl start kube-controller-manager
```

## 配置和启动 kube-scheduler

**创建 kube-scheduler的serivce配置文件**

```bash
# /lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
ExecStart=/opt/kubernetes/server/bin/kube-scheduler \
--leader-elect=true --address=127.0.0.1 --kubeconfig=/etc/kubernetes/kubeconfig \
--logtostderr=false --log-dir=/var/log/k8s --v=0
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target

```

- 本例的`--kubeconfig`中证书仍然使用admin证书

### 启动 kube-scheduler

```bash
# systemctl daemon-reload
# systemctl enable kube-scheduler
# systemctl start kube-scheduler
```

## 验证 master 节点功能

```
# kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
```

其他2台master节点配置和本处一致

## 使用curl请求apiserver

```
$ curl -k --cert /etc/kubernetes/ssl/ca.pem  --key /etc/kubernetes/ssl/ca-key.pem https://10.10.6.201:6443/apis
```



