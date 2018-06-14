启动`httpbin`启用访问日志记录的服务的两个版本

```bash
# cat <<EOF | istioctl kube-inject -f - | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: httpbin-v1
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:8080", "httpbin:app"]
        ports:
        - containerPort: 8080
EOF

```

httpbin-V2：

```bash
# cat <<EOF | istioctl kube-inject -f - | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: httpbin-v2
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: httpbin
        version: v2
    spec:
      containers:
      - image: docker.io/kennethreitz/httpbin
        imagePullPolicy: IfNotPresent
        name: httpbin
        command: ["gunicorn", "--access-logfile", "-", "-b", "0.0.0.0:8080", "httpbin:app"]
        ports:
        - containerPort: 8080
EOF

```

httpbin service

```bash
# cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8080
  selector:
    app: httpbin
EOF

```

### 创建默认路由策略 {#creating-default-routing-policy}

创建一个默认路由规则将所有流量路由到`v1`我们的`httpbin`服务：

```bash
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF

```

现在所有的流量都应该`httpbin v1`服务。我们尝试发送一些流量：

```
$ export SLEEP_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})
$ kubectl exec -it $SLEEP_POD -c sleep -- sh -c 'curl  http://httpbin:8080/headers' | python -m json.tool
{
  "headers": {
    "Accept": "*/*",
    "Content-Length": "0",
    "Host": "httpbin:8080",
    "User-Agent": "curl/7.35.0",
    "X-B3-Sampled": "1",
    "X-B3-Spanid": "eca3d7ed8f2e6a0a",
    "X-B3-Traceid": "eca3d7ed8f2e6a0a",
    "X-Ot-Span-Context": "eca3d7ed8f2e6a0a;eca3d7ed8f2e6a0a;0000000000000000"
  }
}
```

如果我们检查日志`v1`和`v2`我们的`httpbin `pod，我们应该只看到访问日志条目`v1`：

```bash
$ export V1_POD=$(kubectl get pod -l app=httpbin,version=v1 -o jsonpath={.items..metadata.name})
$ kubectl logs -f $V1_POD -c httpbin
127.0.0.1 - - [07/Mar/2018:19:02:43 +0000] "GET /headers HTTP/1.1" 200 321 "-" "curl/7.35.0"
```

```bash
$ export V2_POD=$(kubectl get pod -l app=httpbin,version=v2 -o jsonpath={.items..metadata.name})
$ kubectl logs -f $V2_POD -c httpbin
<none>
```

更改路由规则以将流量镜像到v2

```bash
# cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
    - httpbin
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 100
    mirror:
      host: httpbin
      subset: v2
EOF

```

此路线规则指定我们将100％的流量路由到v1。最后一节指定我们想镜像到`httpbin v2`服务。当流量被镜像时，请求将被发送到镜像服务，其主机/权限标头附加-shadow。例如，cluster-1成为cluster-1-shadow。

现在，如果我们发送流量：

```
$ kubectl exec -it $SLEEP_POD -c sleep -- sh -c 'curl  http://httpbin:8080/headers' | python -m json.tool

```

我们应该看到访问日志记录为`v1`和`v2`。创建的访问日志`v2`是实际要发送的请求`v1`的镜像。

```
$ kubectl logs -f $V1_POD -c httpbin
127.0.0.1 - - [07/Mar/2018:19:02:43 +0000] "GET /headers HTTP/1.1" 200 321 "-" "curl/7.35.0"
127.0.0.1 - - [07/Mar/2018:19:26:44 +0000] "GET /headers HTTP/1.1" 200 321 "-" "curl/7.35.0"
```

```
$ kubectl logs -f $V2_POD -c httpbin
127.0.0.1 - - [07/Mar/2018:19:26:44 +0000] "GET /headers HTTP/1.1" 200 361 "-" "curl/7.35.0"
```



