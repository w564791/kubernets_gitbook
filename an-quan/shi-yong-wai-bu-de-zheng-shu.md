### 开始之前

* 正确安装istio
* 正确安装[bookinfo](https://istio.io/docs/guides/bookinfo/)示例

生成CA证书,脚本来自[istio官方github](https://github.com/istio/istio/edit/release-0.8/security/samples/plugin_ca_certs/)

使用到的ca.cfg

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

脚本**gen\_certs.sh**

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

生成证书目录/usr/local/src/cert/

