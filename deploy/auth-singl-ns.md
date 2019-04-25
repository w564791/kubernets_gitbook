**创建**`devuser-csr.json`**文件**

```json
{
  "CN": "devuser",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```

**生成证书**

在[创建 TLS 证书和秘钥](/1bu-shu-zhi-nan/10-zi-qian-fa-zheng-shu.md)一节中我们将生成的证书和秘钥放在了所有节点的`/etc/kubernetes/ssl`目录下，下面我们再在 master 节点上为 devuser 创建证书和秘钥，在`/etc/kubernetes/ssl`目录下执行以下命令：

执行该命令前请先确保该目录下已经包含如下文件：

```
ca-key.pem  ca.pem ca-config.json  devuser-csr.json
```

```bash
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes devuser-csr.json | cfssljson -bare devuser
2018/01/08 14:43:03 [INFO] generate received request
2018/01/08 14:43:03 [INFO] received CSR
2018/01/08 14:43:03 [INFO] generating key: rsa-2048
2018/01/08 14:43:04 [INFO] encoded CSR
2018/01/08 14:43:04 [INFO] signed certificate with serial number 216264514531257920473704993865556398597116923008
2018/01/08 14:43:04 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
```

这将生成如下文件：

```
devuser.csr  devuser-key.pem  devuser.pem
```

## 权限绑定 {#创建-kubeconfig-文件}

```
# kubectl create rolebinding devuser-binding --clusterrole=admin --user=devuser --namespace=dev
```

* 绑定用户devuser到dev命名空间，给予admin权限
* 当需要赋予其他权限时，需要单独创建相应的权限

## 创建 kubeconfig 文件 {#创建-kubeconfig-文件}

```bash
# 设置集群参数
export KUBE_APISERVER="https://192.168.70.175"
kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=false \
--server=${KUBE_APISERVER} \
--kubeconfig=devuser.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials devuser \
--client-certificate=/etc/kubernetes/ssl/devuser.pem \
--client-key=/etc/kubernetes/ssl/devuser-key.pem \
--embed-certs=false \
--kubeconfig=devuser.kubeconfig

# 设置上下文参数
kubectl config set-context kubernetes \
--cluster=kubernetes \
--user=devuser \
--namespace=dev \
--kubeconfig=devuser.kubeconfig

# 设置默认上下文
kubectl config use-context kubernetes --kubeconfig=devuser.kubeconfig
```

我们现在查看 kubectl 的 context：

```
# KUBECONFIG=~/.kube/config:/etc/kubernetes/ssl/devuser.kubeconfig kubectl config get-contexts
CURRENT   NAME         CLUSTER      AUTHINFO   NAMESPACE
*         default      kubernetes   admin      default
          kubernetes   kubernetes   devuser    dev
          monitor      kubernetes   admin      monitoring
          pxsj         kubernetes   admin      pxsj
          system       kubernetes   admin      kube-system
```

将其用刚生成的`devuser.kubeconfig`替换`~/.kube/config`

```
cp -f /etc/kubernetes/ssl/devuser.kubeconfig /root/.kube/config
```

测试权限：

```
root@node1:~/.kube# kubectl get po
NAME                                  READY     STATUS    RESTARTS   AGE
alertmanager-main-0                   2/2       Running   28         10d
glusterfs-exportor-3385031480-spp42   1/1       Running   23         12d
grafana-3658865556-j7r6t              1/1       Running   13         10d
kube-state-metrics-3978912283-zlwgk   1/1       Running   13         10d
mysql-exportor-2366499531-sd8q5       1/1       Running   12         10d
node-exporter-3f01q                   1/1       Running   29         17d
node-exporter-hzv1v                   1/1       Running   29         17d
node-exporter-kqk3z                   1/1       Running   27         17d
prometheus-k8s-0                      2/2       Running   12         6d

root@node1:~/.kube# kubectl get po -n default
Error from server (Forbidden): pods is forbidden: User "testuser" cannot list pods in the namespace "default"
root@node1:~/.kube# kubectl get ns
Error from server (Forbidden): namespaces is forbidden: User "testuser" cannot list namespaces at the cluster scope
```



# 其实没这么麻烦,给个token就行了,上面都是初学的时候搞的

