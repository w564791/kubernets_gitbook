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
```

```ini
KUBE_API_ADDRESS="--advertise-address=192.168.103.146"
KUBE_ETCD_SERVERS="--etcd-servers=https://k8s-2:2379,https://k8s-3:2379,https://k8s-4:2379"
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
KUBE_ADMISSION_CONTROL="--admission-control=ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota"
KUBE_API_ARGS="--authorization-mode=RBAC --runtime-config=rbac.authorization.k8s.io/v1beta1 --kubelet-https=true --experimental-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv  --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file=/etc/kubernetes/ssl/ca.pem --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem --etcd-cafile=/etc/kubernetes/ssl/ca.pem --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/lib/k8s/apiserver.log --event-ttl=1h"
```

* `--advertise-address` :该地址为`apiserver`集群广播地址,此地址必须能为集群其他部分访问到,如果为空,则使用`--bind-address`，如果`--bind-address`未被制定,那么将使用主机的默认地址；
* `--etcd-servers :`指定etcd集群地址,这里使用https;

* `--admission-control`,必须包含`ServiceAccount`;

* `--authorization-mode=RBAC` 指定在安全端口使用 RBAC 授权模式，拒绝未通过授权的请求;

* `kubelet、kube-proxy、kubectl`部署在其它 `Node`节点上，如果通过**安全端口**访问`kube-apiserver`，则必须先通过 TLS 证书认证，再通过 RBAC 授权

* `--runtime-config`配置为`rbac.authorization.k8s.io/v1beta1`，表示运行时的apiVersion；

* `--service-cluster-ip-range` 指定 Service Cluster IP 地址段，该地址段不能路由可达;

* `--apiserver-count=3`设置集群中master数量

* `--service-node-  port-rang`指定`svc`打开的端口范围

启动`kube-apiserver`

```
# systemctl daemon-reload
```

```bash
# systemctl enable kube-apiserver
# systemctl start kube-apiserver
```

## 配置和启动 kube-controller-manager

**创建 kube-controller-manager的serivce配置文件**

文件路径`/usr/lib/systemd/system/kube-controller-manager.service`

```
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/controller-manager
ExecStart=/usr/local/kubernetes/server/bin/kube-controller-manager \
$KUBE_LOGTOSTDERR \
$KUBE_LOG_LEVEL \
$KUBE_MASTER \
$KUBE_CONTROLLER_MANAGER_ARGS
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

配置文件`/etc/kubernetes/controller-manager`

```
KUBE_MASTER="--master=http://127.0.0.1:8080"
KUBE_CONTROLLER_MANAGER_ARGS="--address=127.0.0.1 --service-cluster-ip-range=10.254.0.0/16 --cluster-name=kubernetes --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem --root-ca-file=/etc/kubernetes/ssl/ca.pem --leader-elect=true"
```

* `--service-cluster-ip-range` 参数指定 `Cluster`中 `Service`的CIDR范围，该网络在各 Node 间必须路由不可达，必须和 `kube-apiserver` 中的参数一致;
* `--leader-elect=true` leader选举
* `--address` 值必须为 `127.0.0.1`，因为当前`kube-apiserver` 期望 `scheduler`和 `controller-manager`在同一台机器;否则会报错

* `--root-ca-file` 用来对 kube-apiserver 证书进行校验，**指定该参数后，才会在Pod 容器的 ServiceAccount 中放置该 CA 证书文件;**

### 启动 kube-controller-manager

```
# systemctl daemon-reload
# systemctl enable kube-controller-manager
# systemctl start kube-controller-manager
```

## 配置和启动 kube-scheduler

**创建 kube-scheduler的serivce配置文件**

文件路径`/usr/lib/systemd/system/kube-scheduler.service`

```bash
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/scheduler
ExecStart=/usr/local/kubernetes/server/bin/kube-scheduler \
$KUBE_LOGTOSTDERR \
$KUBE_LOG_LEVEL \
$KUBE_MASTER \
$KUBE_SCHEDULER_ARGS
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

配置文件`/etc/kubernetes/schedule`

```bash
KUBE_MASTER="--master=http://127.0.0.1:8080"
KUBE_SCHEDULER_ARGS="--leader-elect=true --address=127.0.0.1"
```

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
controller-manager   Healthy   ok
etcd-1               Healthy   {"health": "true"}
scheduler            Healthy   ok
etcd-0               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
```

其他2台master节点配置和本处一致

## 配置和启动 Nginx\(作为3台master的load balancer \)

* ##### Nginx启动在k8s-1上,k8s-1作为复用为node,IP地址为192.168.103.143

编译需要添加nginx的TCP转发模块,我这儿是以前编译好的,直接拿来用,编译参数如下\(Nginx现在已经原生支持TCP转发,我这里用得三方模块\)

```bash
# ./nginx -V
nginx version: nginx/1.8.1
built by gcc 4.4.7 20120313 (Red Hat 4.4.7-4) (GCC)
built with OpenSSL 1.0.1e-fips 11 Feb 2013
TLS SNI support enabled
configure arguments: --prefix=/usr/local/nginx --with-pcre=/usr/local/src/pcre-8.36 --with-zlib=/usr/local/src/zlib-1.2.8 --add-module=/usr/local/src/nginx_tcp_proxy_module-master/
```

看下配置文件

```
# grep -Ev "#|^$" nginx.conf vhost/10050.cnf
nginx.conf:user              nginx;
nginx.conf:worker_processes  1;
nginx.conf:pid        /var/run/nginx.pid;
nginx.conf:events {
nginx.conf:    worker_connections  1024;
nginx.conf:}
nginx.conf:http {
nginx.conf:    default_type  application/octet-stream;
nginx.conf:    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
nginx.conf:                      '$status $body_bytes_sent "$http_referer" '
nginx.conf:                      '"$http_user_agent" "$http_x_forwarded_for"';
nginx.conf:    sendfile        on;
nginx.conf:    keepalive_timeout  65;
nginx.conf:
nginx.conf:}
nginx.conf:include vhost/10050.cnf;
vhost/10050.cnf:tcp {
vhost/10050.cnf:   timeout 1d;
vhost/10050.cnf:   proxy_read_timeout 10d;
vhost/10050.cnf:   proxy_send_timeout 10d;
vhost/10050.cnf:   proxy_connect_timeout 30;
vhost/10050.cnf:   upstream proxy_name {
vhost/10050.cnf:        server k8s-2:6443;
vhost/10050.cnf:        server k8s-3:6443;
vhost/10050.cnf:        server k8s-4:6443;
vhost/10050.cnf:        check interval=60000 rise=2 fall=5 timeout=10000 type=tcp;
vhost/10050.cnf:        }
vhost/10050.cnf:server {
vhost/10050.cnf:        listen       443;
vhost/10050.cnf:        proxy_pass  proxy_name;
vhost/10050.cnf:        }
vhost/10050.cnf:}
```

启动nginx

```bash
/usr/local/src/nginx/nginx/sbin/nginx -c /usr/local/src/ngin/nginx/conf/nginx.conf
```

使用nginx的地址访问apiserver,因为是双向验证,所以需要导出证书为P12文件,安装在windows客户端上

```
openssl pkcs12 -export -in admin.pem -inkey admin-key.pem -out /etc/kubernetes/web-cret.p12
```

![](/assets/chrome-get-apiserver.png)

返回信息:

```
{
  "paths": [
    "/api",
    "/api/v1",
    "/apis",
    "/apis/apps",
    "/apis/apps/v1beta1",
    "/apis/authentication.k8s.io",
    "/apis/authentication.k8s.io/v1",
    "/apis/authentication.k8s.io/v1beta1",
    "/apis/authorization.k8s.io",
    "/apis/authorization.k8s.io/v1",
    "/apis/authorization.k8s.io/v1beta1",
    "/apis/autoscaling",
    "/apis/autoscaling/v1",
    "/apis/autoscaling/v2alpha1",
    "/apis/batch",
    "/apis/batch/v1",
    "/apis/batch/v2alpha1",
    "/apis/certificates.k8s.io",
    "/apis/certificates.k8s.io/v1beta1",
    "/apis/extensions",
    "/apis/extensions/v1beta1",
    "/apis/policy",
    "/apis/policy/v1beta1",
    "/apis/rbac.authorization.k8s.io",
    "/apis/rbac.authorization.k8s.io/v1alpha1",
    "/apis/rbac.authorization.k8s.io/v1beta1",
    "/apis/settings.k8s.io",
    "/apis/settings.k8s.io/v1alpha1",
    "/apis/storage.k8s.io",
    "/apis/storage.k8s.io/v1",
    "/apis/storage.k8s.io/v1beta1",
    "/healthz",
    "/healthz/ping",
    "/healthz/poststarthook/bootstrap-controller",
    "/healthz/poststarthook/ca-registration",
    "/healthz/poststarthook/extensions/third-party-resources",
    "/healthz/poststarthook/rbac/bootstrap-roles",
    "/logs",
    "/metrics",
    "/swagger-ui/",
    "/swaggerapi/",
    "/ui/",
    "/version"
  ]
}
```

查看当前scheduler和controller-manager的leader\(apiserver无状态\)

```
# kubectl get ep -n kube-system kube-controller-manager kube-scheduler -o yaml
apiVersion: v1
items:
- apiVersion: v1
  kind: Endpoints
  metadata:
    annotations:
      control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"k8s-4","leaseDurationSeconds":15,"acquireTime":"2017-07-17T01:30:37Z","renewTime":"2017-07-18T05:28:37Z","leaderTransitions":0}'
    creationTimestamp: 2017-07-17T01:30:37Z
    name: kube-controller-manager
    namespace: kube-system
    resourceVersion: "328391"
    selfLink: /api/v1/namespaces/kube-system/endpoints/kube-controller-manager
    uid: 895ff5e1-6a8f-11e7-b2de-000c29194de3
  subsets: []
- apiVersion: v1
  kind: Endpoints
  metadata:
    annotations:
      control-plane.alpha.kubernetes.io/leader: '{"holderIdentity":"k8s-3","leaseDurationSeconds":15,"acquireTime":"2017-07-17T01:30:36Z","renewTime":"2017-07-18T05:28:35Z","leaderTransitions":0}'
    creationTimestamp: 2017-07-17T01:30:36Z
    name: kube-scheduler
    namespace: kube-system
    resourceVersion: "328392"
    selfLink: /api/v1/namespaces/kube-system/endpoints/kube-scheduler
    uid: 887f7e7e-6a8f-11e7-9362-000c29acf31a
  subsets: []
kind: List
metadata: {}
resourceVersion: ""
selfLink: ""
```

* 此时controller-manager的leader为k8s-4

* 此时scheduler 的leader为k8s-3



