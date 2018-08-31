前面注册node的方式是使用bootstrap发起CSR请求,经server approve后注册到集群,本处不使用bootstrap,方便批量注册

准备csr-josn文件\(注册node 192.168.178.132 \)

```
# cat kubelet-csr.json
{
    "CN": "system:node:192.168.178.132",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [{
        "C": "CN",
        "L": "BeiJing",
        "ST": "BeiJing",
        "O": "system:nodes",
        "OU": "System"
    }]
}
```

生成证书:

```
# cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem -ca-key=/etc/kubernetes/ssl/ca-key.pem --config=/usr/local/src/ssl/ca-config.json -profile=kubernetes kubelet-csr.json | cfssljson -bare kubelet
# ls kubelet*pem
kubelet-key.pem  kubelet.pem
```

生成 `--kubeconfig`文件

```
#export KUBE_APISERVER=https://192.168.178.128:6443

#配置CA证书
# kubectl config set-cluster kubernetes  \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=kubelet.conf
#配置客户端证书
# kubectl config set-credentials system:node:192.168.178.132 \
--client-certificate=kubelet.pem \
--client-key=kubelet-key.pem  \
--embed-certs=true \
--kubeconfig=kubelet.conf
# 配置context
# kubectl config set-context system:node:192.168.178.132 \
--cluster=kubernetes \
--user=system:node:192.168.178.132 \
--kubeconfig=kubelet.conf
#配置当前使用的context
# kubectl config use-context system:node:192.168.178.132 \
--kubeconfig=kubelet.conf
```

查看 kubelet.conf内容

```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ...
    server: https://192.168.178.128:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:node:192.168.178.132
  name: system:node:192.168.178.132
current-context: system:node:192.168.178.132
kind: Config
preferences: {}
users:
- name: system:node:192.168.178.132
  user:
    client-certificate-data: ...
    client-key-data: ...
```

配置kubelet.service\(注意kubelet.conf文件路径\)

```
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/bin/kubelet \
--address=192.168.178.128 \
--hostname-override=192.168.178.128 \
--node-labels=node-role.kubernetes.io/k8s-node=true \
--image-gc-high-threshold=70 \
--image-gc-low-threshold=50 \
--port=10250 \
--network-plugin=cni \
--pod-infra-container-image=docker.io/w564791/pod-infrastructure:latest \
--cluster-dns=10.254.0.2 --cluster-domain=cluster.local.  \
--fail-swap-on=false \
--cgroup-driver=cgroupfs \
--kubeconfig=/etc/kubernetes/kubelet.conf\
--cert-dir=/etc/kubernetes/ssl \
--hairpin-mode promiscuous-bridge \
--serialize-image-pulls=false  \
--allow-privileged=true \
--logtostderr=false --log-dir=/var/log/k8s  \
--v=2
Restart=on-failure
[Install]
WantedBy=multi-user.target
```

PS:  去掉`--bootstrap-kubeconfig`参数,即不使用bootstrap方式注册node;

启动kubelet

```
# systemctl start kubelet
```



