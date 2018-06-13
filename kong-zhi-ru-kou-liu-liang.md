# 控制入口流量 {#title}

部署`httpbin`应用程序

```
# cat httpbin.yaml
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
  selector:
    app: httpbin
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/citizenstig/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        ports:
        - containerPort: 8000
```

```
kubectl apply -f <(istioctl kube-inject -f httpbin.yaml)
```

### 为HTTP配置网关 {#configuring-a-gateway-for-http}

创建一个Istio `Gateway`

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
EOF
```

配置`VirtualService`

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    - uri:
        prefix: /delay
    route:
    - destination:
        port:
          number: 8000
        host: httpbin
EOF
```

请求页面`status`页面

```
# curl --head  http://httpbin.example.com/status/200
HTTP/1.1 200 OK
server: envoy
date: Wed, 13 Jun 2018 08:07:20 GMT
content-type: text/html; charset=utf-8
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 0
x-envoy-upstream-service-time: 4
```

请求`delay`页面

```
# time curl --head  http://httpbin.example.com/delay/2
HTTP/1.1 200 OK
server: envoy
date: Wed, 13 Jun 2018 08:10:59 GMT
content-type: application/json
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 531
x-envoy-upstream-service-time: 2005


real    0m2.018s
user    0m0.004s
sys    0m0.004s
```

### 添加一个安全端口（HTTPS）到gateway\(未验证\) {#add-a-secure-port-https-to-our-gateway}

在本小节中，我们将添加到网关端口443来处理HTTPS流量。我们用证书和私钥创建一个秘密。然后Gateway，除了之前在端口80上定义的服务器之外，我们用先前定义替换为包含端口443上的服务器的定义。

1.创建一个`Kubernetes Secret`来保存密钥/证书

使用kubectl在`istio-system`命名空间创建名为`istio-ingressgateway-certs`的`secret,`istio会自动加载`Secret`

注意:`Secret`必须在`istio-system`并且名称为`istio-ingressgateway-certs,`否则其不能被正确加载` `

`# kubectl create -n istio-system secret tls istio-ingressgateway-certs --key /tmp/tls.key --cert /tmp/tls.crt`

```
cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway # use istio default ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
      privateKey: /etc/istio/ingressgateway-certs/tls.key
    hosts:
    - "httpbin.example.com"
EOF
```



