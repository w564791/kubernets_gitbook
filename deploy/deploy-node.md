# 部署node节点

kubernetes node 节点包含如下组件：

* Calico:  3.0.6 \(cni plugin version: v2.0.5 \)
* Docker 17.03.2-ce
* kubelet
* kube-proxy\(iptables\)

## 配置Calico

详见[Calico部署章节](node/use-calico.md)

## 安装配置docker

本例使用的是docker

安装如下:

```
略...
```

修改docker日志记录方式为json-file\(17.03.2-ce默认日志驱动是json-file无需修改\)

启动docker

```
# systemctl daemon-reload
# systemctl start docker
# systemctl enable docker
```

## 配置 kube-proxy

### requirement

* conntrack程序包

**创建 kube-proxy 的service配置文件**

```bash
# systemctl cat kube-proxy
# /lib/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
[Service]
ExecStart=/opt/kubernetes/server/bin/kube-proxy \
--kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig  --cluster-cidr=10.254.0.0/16 \
--logtostderr=false --log-dir=/var/log/k8s --v=2
ExecStartPost=/sbin/iptables -P FORWARD ACCEPT
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
```

* kube-proxy 根据 `--cluster-cidr` 判断集群内部和外部流量，指定 `--cluster-cidr` 或 `--masquerade-all` 选项后 kube-proxy 才会对访问 Service IP 的请求做 SNAT；

* `--kubeconfig` 指定的配置文件嵌入了 kube-apiserver 的地址、用户名、证书、秘钥等请求和认证信息；

* 预定义的 RoleBinding `cluster-admin` 将User `system:kube-proxy` 与 Role `system:node-proxier` 绑定，该 Role 授予了调用 `kube-apiserver` Proxy 相关 API 的权限；

  kube-proxy可以使用--config文件配置相应的选项

  ```
  apiVersion: kubeproxy.config.k8s.io/v1alpha1
  clientConnection:
    kubeconfig: /etc/kubernetes/kube-proxy.kubeconfig
  clusterCIDR: 10.254.0.0/16
  OOMScoreAdj: -999
  PortRange : "30000-60000"
  healthzBindAddress: 127.0.0.1:10256
  kind: KubeProxyConfiguration
  metricsBindAddress: 127.0.0.1:10249
  mode: ipvs
  
  ```

  使用如下命令查看proxyMode:

  ```
  $  curl 127.0.0.1:10249/proxyMode
  ipvs
  ```

  详细的proxy配置查看kubeadm推荐配置如下:

  ```
  # kubectl get cm -n kube-system kube-proxy -o yaml
  apiVersion: v1
  data:
    config.conf: |-
      apiVersion: kubeproxy.config.k8s.io/v1alpha1
      bindAddress: 0.0.0.0
      clientConnection:
        acceptContentTypes: ""
        burst: 10
        contentType: application/vnd.kubernetes.protobuf
        kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
        qps: 5
      clusterCIDR: 10.244.0.0/16
      configSyncPeriod: 15m0s
      conntrack:
        max: null
        maxPerCore: 32768
        min: 131072
        tcpCloseWaitTimeout: 1h0m0s
        tcpEstablishedTimeout: 24h0m0s
      enableProfiling: false
      healthzBindAddress: 0.0.0.0:10256
      hostnameOverride: ""
      iptables:
        masqueradeAll: false
        masqueradeBit: 14
        minSyncPeriod: 0s
        syncPeriod: 30s
      ipvs:
        excludeCIDRs: null
        minSyncPeriod: 0s
        scheduler: ""
        syncPeriod: 30s
      kind: KubeProxyConfiguration
      metricsBindAddress: 127.0.0.1:10249
      mode: "ipvs"
      nodePortAddresses: null
      oomScoreAdj: -999
      portRange: ""
      resourceContainer: /kube-proxy
      udpIdleTimeout: 250ms
  kind: ConfigMap
  metadata:
    labels:
      app: kube-proxy
    name: kube-proxy
    namespace: kube-system
  
  ```



## 生成kube-proxy.kubeconfig文件

```
export KUBE_APISERVER="https://192.168.178.128:6443"
# 设置集群参数

kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

# 设置客户端认证参数

kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

# 设置上下文参数

kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

# 设置默认上下文

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

### 启动 kube-proxy

```
# systemctl daemon-reload
# systemctl enable kube-proxy
# systemctl start kube-proxy
```

## 

## 安装和配置 kubelet

kubelet 启动时向 kube-apiserver 发送 TLS bootstrapping 请求\(手动注册方式详见[手动注册node章节](node/register-node.md)\)，需要先将 bootstrap token 文件中的 kubelet-bootstrap 用户赋予 system:node-bootstrapper cluster 角色\(role\)，  
然后 kubelet 才能有权限创建认证请求\(certificate signing requests\)，只需要执行一次，多次执行无效，并且抛错，但是没有影响。

```bash
$ kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
```

* `--user=kubelet-bootstrap` 是在 `/etc/kubernetes/token.csv` 文件中指定的用户名，同时也写入了 `/etc/kubernetes/bootstrap.kubeconfig` 文件；

### 创建 kubelet 的service配置文件

* ##### kubelet 依赖docker服务,需要先启动docker
* ##### kubelet 启动之前工作目录必须创建,否则会报错,如下:

  ```
     /usr/local/kubernetes/server/bin/kubele :No such file or ...
  ```

`kubelet`启动文件

```
# systemctl cat kubelet
# /lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/bin/kubelet \
--hostname-override=192.168.178.128 \
--node-labels=node-role.kubernetes.io/k8s-node=true \
--pod-infra-container-image=docker.io/w564791/pod-infrastructure:latest \
--bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
--kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
--cert-dir=/etc/kubernetes/ssl \
--logtostderr=false --log-dir=/var/log/k8s  \
--v=2 \
--config=/etc/kubernetes/kubelet.yaml  \
--allow-privileged=true  \
--network-plugin=cni
Restart=on-failure
```

* `--address` 不能设置为 `127.0.0.1`，否则后续 Pods 访问 kubelet 的 API 接口时会失败，因为 Pods 访问的 `127.0.0.1` 指向自己而不是 kubelet；

* `--experimental-bootstrap-kubeconfig` 指向 bootstrap kubeconfig 文件，kubelet 使用该文件中的用户名和 token 向 kube-apiserver 发送 TLS Bootstrapping 请求；

* 管理员通过了 CSR 请求后，kubelet 自动在 `--cert-dir` 目录创建证书和私钥文件\(`kubelet-client.crt` 和 `kubelet-client.key`\)，然后写入 `--kubeconfig` 文件；

* `--cluster-dns` 指定 kubedns 的 Service IP\(可以先分配，后续创建 kube-dns 服务时指定该 IP,这里暂时先不加,否则会启动失败\)，`--cluster-domain` 指定域名后缀，这两个参数同时指定后才会生效；

* `--kubeconfig=/etc/kubernetes/kubelet.kubeconfig`中指定的`kubelet.kubeconfig`文件在第一次启动kubelet之前并不存在，请看下文，当通过CSR请求后会自动生成`kubelet.kubeconfig`文件，如果你的节点上已经生成了`~/.kube/config`文件，你可以将该文件拷贝到该路径下，并重命名为`kubelet.kubeconfig`，所有node节点可以共用同一个kubelet.kubeconfig文件，这样新添加的节点就不需要再创建CSR请求就能自动添加到kubernetes集群中,同样，在任意能够访问到kubernetes集群的主机上使用`kubectl —kubeconfig`命令操作集群时，只要使用`~/.kube/config`文件就可以通过权限认证，因为这里面已经有认证信息并认为你是admin用户，对集群拥有所有权限,但是**通常我们不建议这么做**

* --pod-infra-container-image 指定POD运行时的基础镜像,建议先下载下来

* --node-status-update-frequency 设置kublet每隔多久向apiserver报告状态,默认是10s

* --docker-disable-shared-pid 在1.7版本中，部署glusterfs需要添加此项

* --network-plugin=cni   使用cni插件

* --fail-swap-on=false   不使用swap

  _**上列参数部分在--config指定的配置文件里设置**_,该文件可以使用如下命令从ready的node上获取

  ```
  # curl -sSL http://localhost:8080/api/v1/nodes/192.168.178.128/proxy/configz | jq '.kubeletconfig|.kind="KubeletConfiguration"|.apiVersion="kubelet.config.k8s.io/v1beta1"'
  ```

```
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  x509:
    clientCAFile: "/etc/kubernetes/ssl/ca.pem"
  webhook:
    enabled: true
    cacheTTL: 1s
  anonymous:
    enabled: false
authorization:
  #mode: Webhook
  mode: AlwaysAllow
  webhook:
    cacheAuthorizedTTL: 1s
    cacheUnauthorizedTTL: 1s
address: 192.168.178.128
#tlsCertFile: "/etc/kubernetes/ssl/kubelet.crt"
#tlsPrivateKeyFile: "/etc/kubernetes/ssl/kubelet.key"
enableDebuggingHandlers: true
port: 10250
#readOnlyPort: 10255
failSwapOn: false
cgroupDriver: cgroupfs
cgroupsPerQOS: true
hairpinMode: promiscuous-bridge
oomScoreAdj: -999
registryBurst: 10
registryPullQPS: 5
kubeAPIBurst: 10
kubeAPIQPS: 5
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
imageMinimumGCAge: 2m0s
iptablesDropBit: 15
iptablesMasqueradeBit: 14
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
eventBurst: 10
eventRecordQPS: 5
configMapAndSecretChangeDetectionStrategy: Watch
####硬驱逐阈值####
evictionHard:
  imagefs.available: 15%
  memory.available: 200Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
####软驱逐阈值####
evictionSoft:
  memory.available: 10%
  nodefs.available: 2Gi
####驱逐间隔####
evictionSoftGracePeriod:
  memory.available: 1m30s
  nodefs.available: 1m30s
evictionPressureTransitionPeriod: 30s
evictionMaxPodGracePeriod: 120
####驱逐时需要释放的最少资源####
evictionMinimumReclaim:
  imagefs.available: 2Gi
  memory.available: 0Mi
  nodefs.available: 500Mi
####为系统预留的资源####
systemReserved:
  cpu: 100m
  ephemeral-storage: 1Gi
  memory: 200Mi
####为kubelet预留的资源####
kubeReserved:
  cpu: 100m
  ephemeral-storage: 1Gi
  memory: 200Mi
serializeImagePulls: false
####自动轮替证书####
featureGates:
  RotateKubeletClientCertificate: true
  RotateKubeletServerCertificate: true
clusterDomain: cluster.local.
clusterDNS:
- 10.254.0.2

```

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
NAME                                                   AGE       REQUESTOR           CONDITION
node-csr-AI9glSTZQ-knI6JnjYl6Cm_5E4fgELRttJgxK3qVLoA   1h        kubelet-bootstrap   Pending
```

通过 CSR 请求

```bash
# kubectl certificate approve node-csr-AI9glSTZQ-knI6JnjYl6Cm_5E4fgELRttJgxK3qVLoA
certificatesigningrequest "node-csr-AI9glSTZQ-knI6JnjYl6Cm_5E4fgELRttJgxK3qVLoA" approved
# kubectl get no
NAME              STATUS                        ROLES      AGE       VERSION
192.168.178.128   Ready                         k8s-node   1h        v1.10.2
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

## 验证测试:

创建2个nginx的deploy:

```bash
# kubectl run nginx --image=nginx --replicas=2 --labels=app=nginx
# kubectl create svc clusterip nginx --tcp=80:80
```

查看pod

```bash
#  kubectl get po --selector=app=nginx -o wide 
NAME                              READY     STATUS    RESTARTS   AGE       IP               NODE
nginx-7c87cc96df-wz2f2            1/1       Running   0          2m        172.20.112.121   192.168.178.128
nginx-7c87cc96df-4zjbr            1/1       Running   0          2m        172.20.112.73   192.168.178.128
```

查看ep

```
# kubectl get ep --selector=app=nginx
NAME      ENDPOINTS                            AGE
nginx     172.20.112.121:80,172.20.112.73:80   1m
```

查看svc

```
#  kubectl get svc --selector=app=nginx
NAME      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx     ClusterIP   10.254.92.250   <none>        80/TCP    1m
```

note: 所有`kubectl`命令都能使用`-v=10`来添加更详细输出

使用http命令get svc地址:

```
# http 10.254.92.250
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

在master上查看注册node上的容器日志时,需要在apiserver中加上如下参数

```
--kubelet-client-certificate=/etc/kubernetes/ssl/kubernetes.pem 
--kubelet-client-key=/etc/kubernetes/ssl/kubernetes-key.pem 
```

丢失该参数时查看日志报错如下

```
# kubectl  logs ngins-574895dbf4-tvvgg  -c nginxs

error: You must be logged in to the server (the server has asked for the client to provide credentials ( pods/log  nginx-574895dbf4-tvvgg))
```



