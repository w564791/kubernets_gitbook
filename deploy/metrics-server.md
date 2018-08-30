自从kubernetes1.8版本起,Kubernetes通过Metrics API提供资源使用指标,例如容器CPU或者内存使用情况,这些度量用户可以直接访问,例如通过kubectl top命令,或者由集群的control-manager使用来进行决策(例如HPA)

## [Metrics API](https://kubernetes.io/docs/tasks/debug-application-cluster/core-metrics-pipeline/#the-metrics-api)

通过Metrics API，您可以获得给定节点或给定pod当前使用的资源量。此API不存储度量标准值，因此例如在10分钟前获取给定节点使用的资源量是不可能的。

API与任何其他API没有区别：

- 它可以通过与`/apis/metrics.k8s.io/`路径下的其他Kubernetes API相同的端点发现
- 它提供相同的安全性，可扩展性和可靠性保证



## 配置K8S Aggregation Layer

Aggregation Layer允许kubernetes apiserver使用其他拓展API,这些API不是kubernetes API的狠心部分

## 启用apiserver配置

```
--requestheader-client-ca-file=<path to aggregator CA cert>
--requestheader-allowed-names=aggregator[,...]
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-group-headers=X-Remote-Group
--requestheader-username-headers=X-Remote-User
--proxy-client-cert-file=<path to aggregator proxy cert>
--proxy-client-key-file=<path to aggregator proxy key>
```

如果您未在运行API服务器的主机上运行kube-proxy，则必须确保使用以下apiserver标志启用系统:



```
--enable-aggregator-routing=true
```



## 配置证书:

证书配置方式和[kube-proxy部署](cacert.md)使用的证书类似:

```json
# cat aggregator.json
{
    "CN": "metrics-server",
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

生成证书:

```
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  aggregator.json|cfssljson -bare aggregator
# ls aggregator*
aggregator.csr  aggregator.json  aggregator-key.pem  aggregator.pem
```

在集群中创建RBAC规则,(可以保证kubectl top po|no能正常查询,其他没做测试)

```yaml
# cat aggregator.yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-metrics
  namespace: kube-system
rules:
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods","nodes"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-metrics-binds
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: read-metrics
subjects:
- kind: User
  name: metrics-server
  namespace: kube-system

```



```bash
# kubectl create -f aggregator.yaml
```



查看apiserver最终配置

```bash
# systemctl cat kube-apiserver
# /lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service
[Service]
ExecStart=/bin/kube-apiserver \
--logtostderr=false --log-dir=/var/log/k8s -v=0 --allow-privileged=true \
--bind-address=192.168.178.128 --secure-port=6443 --insecure-bind-address=127.0.0.1 --insecure-port=8080 \
--etcd-servers=https://192.168.178.128:2379 \
--service-cluster-ip-range=10.254.0.0/16 --kubelet-https=true --service-node-port-range=79-60000  \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction \
--authorization-mode=Node,RBAC \
--enable-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv \
--enable-garbage-collector \
--enable-logs-handler \
--tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
--tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
--client-ca-file=/etc/kubernetes/ssl/ca.pem \
#--kubelet-client-certificate=/etc/kubernetes/ssl/kubernetes.pem \
#--kubelet-client-key=/etc/kubernetes/ssl/kubernetes-key.pem \
--service-account-key-file=/etc/kubernetes/ssl/ca-key.pem  \
--requestheader-client-ca-file=/etc/kubernetes/ssl/ca.pem \
--proxy-client-cert-file=/etc/kubernetes/ssl/aggregator.pem \
--proxy-client-key-file=/etc/kubernetes/ssl/aggregator-key.pem \
--requestheader-extra-headers-prefix=X-Remote-Extra- \
--requestheader-group-headers=X-Remote-Group \
--requestheader-username-headers=X-Remote-User \
--enable-aggregator-routing=true \
--requestheader-allowed-names=metrics-server,admin \
--etcd-cafile=/etc/kubernetes/ssl/ca.pem \
--etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \
--etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \
--apiserver-count=1  \
--storage-backend=etcd3 \
--audit-policy-file=/etc/kubernetes/audit.yaml --audit-log-path=/var/log/audit \
--audit-log-maxage=1 --audit-log-maxbackup=1 --audit-log-maxsize=1024
Restart=always
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target

```

