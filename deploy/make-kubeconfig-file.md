### 创建 kubeconfig 文件

`kubelet、kube-proxy`等 `Node`机器上的进程与 `Master`机器的`kube-apiserver`进程通信时需要认证和授权；

`kubernetes`1.4 开始支持由`kube-apiserver`为客户端生成 `TLS`证书的[`TLS Bootstrapping`](https://kubernetes.io/docs/admin/kubelet-tls-bootstrapping/)功能，这样就不需要为每个客户端生成证书了；该功能当前仅支持为kubelet生成证书；

### 创建 TLS Bootstrapping Token

**Token auth file**

Token可以是任意的包涵128 bit的字符串，可以使用安全的随机数发生器生成。

```
# export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
# cat > token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```

将token.csv发到所有机器（Master 和 Node）的`/etc/kubernetes/`目录;

### 创建 kubelet bootstrapping kubeconfig 文件

```bash
# cd /etc/kubernetes
# 我这里的KUBE_APISERVER设置的ng(负载均衡器)的地址
# export KUBE_APISERVER="https://xxxx"
# 设置集群参数
# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
# 设置客户端认证参数
# kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig
# 设置上下文参数
# kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig
# # 设置默认上下文
# kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
```

* `--embed-certs` 为 true 时表示将`certificate-authority` 证书写入到生成的 `bootstrap.kubeconfig` 文件中；本处设置为false,别问我为什么,宝宝心里苦
* 设置客户端认证参数时没有指定秘钥和证书，后续由`kube-apiserver`自动生成；

### 创建 kube-proxy kubeconfig 文件

```bash
# 设置集群参数
# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
# 设置客户端认证参数
# kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=false \
  --kubeconfig=kube-proxy.kubeconfig
# 设置上下文参数
# kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
# 设置默认上下文
# kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

* 设置集群参数和客户端认证参数时 `--embed-certs`都为 `true`，这会将 `certificate-authority、client-certificate` 和 `client-key`指向的证书文件内容写入到生成的`kube-proxy.kubeconfig`文件中；


### 创建 kube-controller-manager kubeconfig 文件

```bash
# 设置集群参数
# kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kubeconfig
# 设置客户端认证参数
# kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/etc/kubernetes/ssl/kube-controller-manager.pem \
  --client-key=/etc/kubernetes/ssl/kube-controller-manager.pem \
  --embed-certs=false \
  --kubeconfig=kubeconfig
# 设置上下文参数
# kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=kubeconfig
# 设置默认上下文
# kubectl config use-context default --kubeconfig=kubeconfig
```

- 

### 分发 kubeconfig 文件

将两个 `kubeconfig`文件分发到所有 Node 机器的`/etc/kubernetes/`目录

### 创建 kubectl kubeconfig 文件

```bash
# 设置集群参数
$ kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=false \
  --server=${KUBE_APISERVER}
$ # 设置客户端认证参数
$ kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --embed-certs=false \
  --client-key=/etc/kubernetes/ssl/admin-key.pem
$ # 设置上下文参数
$ kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin
$ # 设置默认上下文
$ kubectl config use-context kubernetes
```

看下这个文件:

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority: ...
    server: https://xxxx
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
    client-certificate: ...
    client-key: ...
```





