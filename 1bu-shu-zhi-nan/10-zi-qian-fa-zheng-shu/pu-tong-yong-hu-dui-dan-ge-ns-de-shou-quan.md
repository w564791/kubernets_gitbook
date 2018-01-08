**创建`devuser-csr.json`文件**

```
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

**生成 CA 证书和私钥**

在[创建 TLS 证书和秘钥](/1bu-shu-zhi-nan/10-zi-qian-fa-zheng-shu.md)一节中我们将生成的证书和秘钥放在了所有节点的`/etc/kubernetes/ssl`目录下，下面我们再在 master 节点上为 devuser 创建证书和秘钥，在`/etc/kubernetes/ssl`目录下执行以下命令：

执行该命令前请先确保该目录下已经包含如下文件：

```
ca-key.pem  ca.pem ca-config.json  devuser-csr.json
```

```
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



