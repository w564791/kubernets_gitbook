### 开始之前

* 正确安装istio\(本处示例未启用tls,只是做证书内容验证\)
* 正确安装[bookinfo](https://istio.io/docs/guides/bookinfo/)示例

生成CA证书,脚本来自[istio官方github](https://github.com/istio/istio/edit/release-0.8/security/samples/plugin_ca_certs/)

gen\_certs.sh脚本使用到的ca.cfg

```
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = Sunnyvale
O = Istio
CN = Istio CA

[v3_req]
keyUsage = keyCertSign
basicConstraints = CA:TRUE
subjectAltName = @alt_names

[alt_names]
DNS.1 = ca.istio.io
```

执行脚本**gen\_certs.sh**

```
echo 'Generate key and cert for root CA.'
openssl req -newkey rsa:2048 -nodes -keyout root-key.pem -x509 -days 36500 -out root-cert.pem <<EOF
US
California
Sunnyvale
Istio
Test
Root CA
testrootca@istio.io


EOF

echo 'Generate private key for Istio CA.'
openssl genrsa -out ca-key.pem 2048

echo 'Generate CSR for Istio CA.'
openssl req -new -key ca-key.pem -out ca-cert.csr -config ca.cfg -batch -sha256

echo 'Sign the cert for Istio CA.'
openssl x509 -req -days 36500 -in ca-cert.csr -sha256 -CA root-cert.pem -CAkey root-key.pem -CAcreateserial -out ca-cert.pem -extensions v3_req -extfile ca.cfg

rm *csr
rm *srl

echo 'Generate cert chain file.'
cp ca-cert.pem cert-chain.pem
```

生成证书目录`/usr/local/src/cert/`

```
# ls /usr/local/src/cert/
ca-cert.pem  ca.cfg  ca-key.pem  cert-chain.pem  cert.sh  root-cert.pem  root-key.pem
```

## 插入现有证书和密钥 {#plugging-in-the-existing-certificate-and-key}

以下步骤可以将证书和密钥插入到Citadel中：

1.创建一个秘密cacert，包括所有输入文件ca-cert.pem，ca-key.pem，root-cert.pem和cert-chain.pem：

```
# kubectl create secret generic cacerts -n istio-system --from-file=/usr/local/src/cert/ca-cert.pem     --from-file=/usr/local/src/cert/ca-key.pem --from-file=/usr/local/src/cert/root-cert.pem     --from-file=/usr/local/src/cert/cert-chain.pem
```

2.重新部署Citadel，它从安装文件中读取证书和密钥：

```
# kubectl apply -f install/kubernetes/istio-citadel-plugin-certs.yaml
```

PS:如果您使用不同的证书secret名称，则需要更改`istio-citadel-plugin-certs.yaml`文件中的相应的参数

3.为了确保sidecar拿到新的证书,删除Citadel生成的secret\(以istio.\*命名\)

```
# kubectl delete secret istio.default
```

## 验证新证书 {#verifying-the-new-certificates}

请确保openssl已经安装

检索ratings的证书

    # RATINGSPOD=`kubectl get pods -l app=ratings -o jsonpath='{.items[0].metadata.name}'`
    # kubectl exec -it $RATINGSPOD -c istio-proxy -- /bin/cat /etc/certs/root-cert.pem > /tmp/pod-root-cert.pem
    # kubectl exec -it $RATINGSPOD -c istio-proxy -- /bin/cat /etc/certs/cert-chain.pem > /tmp/pod-cert-chain.pem

验证根证书自己的证书相同

```
# openssl x509 -in /usr/local/src/cert/root-cert.pem -text -noout > /tmp/root-cert.crt.txt
# openssl x509 -in /tmp/pod-root-cert.pem -text -noout > /tmp/pod-root-cert.crt.txt
# diff /tmp/root-cert.crt.txt /tmp/pod-root-cert.crt.txt
```

预期输出结果为空

验证sidecar中的CA证书

```
# tail -n 22 /tmp/pod-cert-chain.pem > /tmp/pod-cert-chain-ca.pem
# openssl x509 -in /usr/local/src/cert/ca-cert.pem -text -noout > /tmp/ca-cert.crt.txt
# openssl x509 -in /tmp/pod-cert-chain-ca.pem -text -noout > /tmp/pod-cert-chain-ca.crt.txt
# diff /tmp/ca-cert.crt.txt /tmp/pod-cert-chain-ca.crt.txt
```

期望输出结果为空

验证根针数和负载证书的证书链

```
# head -n 21 /tmp/pod-cert-chain.pem > /tmp/pod-cert-chain-workload.pem
# openssl verify -CAfile <(cat /usr/local/src/cert/ca-cert.pem /usr/local/src/cert/root-cert.pem) /tmp/pod-cert-chain-workload.pem
/tmp/pod-cert-chain-workload.pem: OK
```

### 清理现场



