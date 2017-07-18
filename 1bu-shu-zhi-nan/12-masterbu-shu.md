# 部署高可用 kubernetes master 集群

kubernetes master 节点包含的组件：

* kube-apiserver
* kube-scheduler
* kube-controller-manager

目前这三个组件需要部署在同一台机器上。

* `kube-scheduler`、`kube-controller-manager`和`kube-apiserver`三者的功能紧密相关；同时只能有一个`kube-scheduler`、`kube-controller-manager`
* 进程处于工作状态，如果运行多个，则需要通过选举产生一个 leader；

此处记录部署一个三个节点的高可用 kubernetes master 集群步骤,后续创建一个`load balancer`\(`nginx,`部署在`k8s-1`上\)来代理访问`kube-apiserver` 的请求

下载响应版本的二进制包

此处使用的是[v1.6.6](https://github.com/w564791/kubernetes/archive/v1.6.6.tar.gz)版本

```
# wget https://github.com/kubernetes/kubernetes/archive/v1.6.6.tar.gz
# tar -xf v1.6.6.tar.gz && cd kubernetes-1.6.6/cluster/ &&echo "v1.6.6" > ../version
# ./get-kube-binaries.sh
...
# ls ../server/ ../client/
../client/:
bin  kubernetes-client-linux-amd64.tar.gz

../server/:
kubernetes-server-linux-amd64.tar.gz

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

## 配置和启动 kube-apiserver

**创建 kube-apiserver的service配置文件**

api-server `serivce`配置文件`/usr/lib/systemd/system/kube-apiserver.service`内容：

```
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service
[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/apiserver
ExecStart=/usr/local/kubernetes/server/bin/kube-apiserver \
$KUBE_LOGTOSTDERR \
$KUBE_LOG_LEVEL \
$KUBE_ETCD_SERVERS \
$KUBE_API_ADDRESS \
$KUBE_API_PORT \
$KUBELET_PORT \
$KUBE_ALLOW_PRIV \
$KUBE_SERVICE_ADDRESSES \
$KUBE_ADMISSION_CONTROL \
$KUBE_API_ARGS
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

配置`apiserver ,controller-manager,scheduler`公用配置文件`/etc/kubernetes/config`

```
# cat /etc/kubernetes/config
```

```
KUBE_LOGTOSTDERR="--logtostderr=false --log-dir=/var/lib/k8s"
KUBE_LOG_LEVEL="--v=0"
KUBE_ALLOW_PRIV="--allow-privileged=true"
```

* --logtostderr=false 是否将日志输出到标准输出,这里选择false,输出到 `--log-dir=/var/lib/k8s`目录
* `--v=0` 设置日志等级

```ini
# cat /etc/kubernetes/apiserver
KUBE_API_ADDRESS="--advertise-address=192.168.103.146"
KUBE_ETCD_SERVERS="--etcd-servers=https://k8s-2:2379,https://k8s-3:2379,https://k8s-4:2379"
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
KUBE_ADMISSION_CONTROL="--admission-control=ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota"
KUBE_API_ARGS="--authorization-mode=RBAC --runtime-config=rbac.authorization.k8s.io/v1beta1 --kubelet-https=true --experimental-bootstrap-token-auth --token-auth-file=/etc/kubernetes/ssl/token.csv  --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file=/etc/kubernetes/ssl/ca.pem --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem --etcd-cafile=/etc/kubernetes/ssl/ca.pem --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/lib/k8s/apiserver.log --event-ttl=1h"

```



