## 集群部件所需证书

| CA&Key | etcd | kube-apiserver | kube-proxy | kubelet | kubectl | flanneld |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| ca.pem | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ | ✔️ |
| ca-key.pem |  |  |  |  |  |  |
| kubernetes.pem | ✔️ | ✔️ |  |  |  | ✔️ |
| kubernetes-key.pem | ✔️ | ✔️ |  |  |  | ✔️ |
| kube-proxy.pem |  |  | ✔️ |  |  |  |
| kube-proxy-key.pem |  |  | ✔️ |  |  |  |
| admin.pem |  |  |  |  | ✔️ |  |
| admin-key.pem |  |  |  |  | ✔️ |  |

## 安装CFSSL

```bash
# wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o /usr/local/bin/cfssl && chmod +x /usr/local/bin/cfssl
# wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o /usr/local/bin/cfssljson && chmod +x /usr/local/bin/cfsslcfssljson
# wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -o /usr/local/bin//cfssl-certinfo && chmod +x /usr/local/bin/cfssl-certinfo
```

```

```

## 创建CA \(Certificate Authority\)

#### 创建CA文件

```bash
# cd /usr/loca/src && mkdir ssl && cd $_
# cfssl print-defaults config > config.json
# cfssl print-defaults csr > csr.json
```

手动创建CA配置文件

```shell
# cat ca-config.json
```

```json
{
    "signing": {
        "default": {
            "expiry": "87600h"
        },
        "profiles": {
            "kubernetes": {
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ],
                "expiry": "87600h"
            }
        }
    }
}
```

##### 字段说明:

* `ca-config.json` 可以定义读个 profiles,分别制定不同的国企时间,使用场景等参数;后续在签名时使用某个`profile`;
* `signing`:表示该证书可以用于签名其他证书;生成的`ca.pem`中`CA=TRUE`;
* `server auth` :表示client可以用该`CA`对`server`提供的证书进行验证;
* `client auth` :表示`server`可以用该`CA`对`client`提供的证书进行验证;

##### 创建CA证书签名请求:

```
# cat ca-csr.json
```

```json
{
    "CN": "kubernetes",
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

"CN"：`Common Name，kube-apiserver` 从证书中提取该字段作为请求的用户名 `(User Name)`;浏览器使用该字段验证网站是否合法;

"O"：`Organization，kube-apiserver`从证书中提取该字段作为请求用户所属的组`(Group)`;

#### 生成 CA 证书和私钥

```
# cfssl gencert -initca ca-csr.json | cfssljson -bare ca
# ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

## 创建 kubernetes 证书

```
# cat kubernetes-csr.json
```

```
{
    "CN": "kubernetes",
    "hosts": [
        "127.0.0.1",
        "10.254.0.1",
        "k8s-1",
        "k8s-2",
        "k8s-3",
        "k8s-4",
    ],
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

* 如果`hosts`字段不为空,则需要制定授权证书的IP或域名列表,由于该证书后续江北etcd集群和`kubernetes  master`集群所使用,所以上面指定了`etcd`集群,master集群的主机域名,`kubernetes`**服务的服务 IP **一般是`kue-apiserver`指定的`service-cluster-ip-range`网段的第一个IP，如 `10.254.0.1`,一定要加,不然后面会像我一样遇到很多坑,我的例子里面是没有加的

**生成 kubernetes 证书和私钥**

```
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
# ls kuberntes*
kubernetes.csr  kubernetes-csr.json  kubernetes-key.pem  kubernetes.pem
```

## 创建 admin 证书

```
# cat admin-csr.json
```

```
{
    "CN": "admin",
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
            "O": "system:masters",
            "OU": "System"
        }
    ]
}
```

* 后续`kube-apiserver` 使用 `RBAC`对客户端\(如 `kubelet、kube-proxy、Pod`\)请求进行授权；
* `kube-apiserver` 预定义了一些 `RBAC`使用的 `RoleBindings`，如 `cluster-admin` 将 `Group system:masters`与 `Role cluster-admin` 绑定，该 `Role` 授予了调用`kube-apiserver`的所有 API的权限；
* `OU`指定该证书的 `Group`为 `system:masters，kubelet` 使用该证书访问 `kube-apiserver`时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 `system:masters`，所以被授予访问所有 API 的权限；

生成 admin 证书和私钥

```
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
# ls admin*
admin.csr admin-csr.json admin-key.pem admin.pem
```

#### 创建kube-proxy 证书

创建 kube-proxy 证书签名请求

```
# cat kube-proxy-csr.json
```

```
{
    "CN": "system:kube-proxy",
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

* `CN`指定该证书的 `User`为 `system:kube-proxy`；
* `kube-apiserver`预定义的`RoleBinding cluster-admin` 将`User system:kube-proxy` 与 `Role system:node-proxier`绑定，该 `Role` 授予了调用 `kube-apiserver Proxy`相关 API 的权限；

生成 kube-proxy 客户端证书和私钥

```
#  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
# ls kube-proxy*
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```

## 校验证书

以 `kubernetes`证书为例

#### 使用`opsnssl`命令

```
# openssl x509  -noout -text -in  kubernetes.pem
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            07:10:33:5b:dc:9d:bc:bc:29:ab:f2:45:84:90:3e:5a:86:3e:ff:08
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=CN, ST=BeiJing, L=BeiJing, O=k8s, OU=System, CN=kubernetes
        Validity
            Not Before: Jul 11 01:26:00 2017 GMT
            Not After : Jul  9 01:26:00 2027 GMT
        Subject: C=CN, ST=BeiJing, L=BeiJing, O=k8s, OU=System, CN=kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
....
            X509v3 Subject Alternative Name:
                DNS:k8s-1, DNS:k8s-2, DNS:k8s-3, DNS:k8s-4, IP Address:127.0.0.1
....
```

* 确认`Issuer`字段的内容和 `ca-csr.json`一致；
* 确认 `Subject`字段的内容和 `kubernetes-csr.json` 一致；
* 确认 `X509v3 Subject Alternative Name`字段的内容和 `kubernetes-csr.json` 一致；
* 确认`X509v3 Key Usage、Extended Key Usage` 字段的内容和 `ca-config.json 中 kubernetes profile`一致；

#### 使用`cfssl-certinfo`命令

```
$ cfssl-certinfo -cert kubernetes.pem
{
  "subject": {
    "common_name": "kubernetes",
    "country": "CN",
    "organization": "k8s",
    "organizational_unit": "System",
    "locality": "BeiJing",
    "province": "BeiJing",
    "names": [
      "CN",
      "BeiJing",
      "BeiJing",
      "k8s",
      "System",
      "kubernetes"
    ]
  },
  "issuer": {
    "common_name": "kubernetes",
    "country": "CN",
    "organization": "k8s",
    "organizational_unit": "System",
    "locality": "BeiJing",
    "province": "BeiJing",
    "names": [
      "CN",
      "BeiJing",
      "BeiJing",
      "k8s",
      "System",
      "kubernetes"
    ]
  },
  "serial_number": "40324221304470453898143986608059802229221031688",
  "sans": [
    "k8s-1",
    "k8s-2",
    "k8s-3",
    "k8s-4",
    "127.0.0.1"
  ],
...
```

## 分发证书

将生成的证书和秘钥文件（后缀名为.pem）拷贝到所有机器的`/etc/kubernetes/ssl`目录下备用；

```
# for i in k8s-1 k8s-2 k8s-3 k8s-4 ;do scp *pem root@$i:/etc/kubernetes/ssl/ ;done
```

参考文档:

\[1\]: [https://o-my-chenjian.com/2017/04/25/Security-Settings-Of-K8s/](https://o-my-chenjian.com/2017/04/25/Security-Settings-Of-K8s/)

