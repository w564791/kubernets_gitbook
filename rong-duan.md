### base:

app: httpbin

```
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

### 创建断路设置

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      http:
        consecutiveErrors: 1
        interval: 1s
        baseEjectionTime: 3m
        maxEjectionPercent: 100
EOF
```

### 启动客户端

```
cat <<EOF | istioctl  kube-inject -f -|kubectl create -f -
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: fortio-deploy
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: fortio
    spec:
      containers:
      - name: fortio
        image: istio/fortio:latest_release
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http-fortio
        - containerPort: 8079
          name: grpc-ping
EOF
```

检查客户端d奥httpbin的连接

```
root@128:/home/kinglong/istio# FORTIO_POD=$(kubectl get pod | grep fortio | awk '{ print $1 }')
root@128:/home/kinglong/istio# echo $FORTIO_POD
fortio-deploy-c897c6cc7-rxc6q
root@128:/home/kinglong/istio#  kubectl exec -it $FORTIO_POD  -c fortio /usr/local/bin/fortio -- load -curl  http://httpbin:8000/get
HTTP/1.1 200 OK
server: envoy
date: Thu, 14 Jun 2018 06:48:06 GMT
content-type: application/json
access-control-allow-origin: *
access-control-allow-credentials: true
content-length: 414
x-envoy-upstream-service-time: 4

{
  "args": {},
  "headers": {
    "Content-Length": "0",
    "Host": "httpbin:8000",
    "User-Agent": "istio/fortio-0.11.0",
    "X-B3-Sampled": "1",
    "X-B3-Spanid": "5301dafc1b36da8f",
    "X-B3-Traceid": "5301dafc1b36da8f",
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000",
    "X-Request-Id": "64a298ed-1584-923c-ab5c-b999624941d8"
  },
  "origin": "127.0.0.1",
  "url": "http://httpbin:8000/get"
}
```

可以按到,请求成功,下面开始搞事情

在断路设置中，我们指定了maxConnections：1和http1MaxPendingRequests：1.这意味着如果我们超过一个连接并且同时请求，我们应该看到istio-proxy打开电路以进一步请求/连接。 让我们尝试两个并发连接（-c 2）并发送20个请求（-n 20）

```
root@128:/home/kinglong/istio# kubectl exec -it $FORTIO_POD  -c fortio /usr/local/bin/fortio -- load -c 2 -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get
06:50:06 I logger.go:97> Log level is now 3 Warning (was 2 Info)
Fortio 0.11.0 running at 0 queries per second, 4->4 procs, for 20 calls: http://httpbin:8000/get
Starting at max qps with 2 thread(s) [gomax 4] for exactly 20 calls (10 per thread + 0)
06:50:06 W http_client.go:584> Parsed non ok code 503 (HTTP/1.1 503)
06:50:06 W http_client.go:584> Parsed non ok code 503 (HTTP/1.1 503)
Ended after 103.306165ms : 20 calls. qps=193.6
Aggregated Function Time : count 20 avg 0.009788651 +/- 0.004691 min 0.000919654 max 0.020017975 sum 0.195773021
# range, mid point, percentile, count
>= 0.000919654 <= 0.001 , 0.000959827 , 5.00, 1
> 0.005 <= 0.006 , 0.0055 , 15.00, 2
> 0.006 <= 0.007 , 0.0065 , 20.00, 1
> 0.007 <= 0.008 , 0.0075 , 50.00, 6
> 0.008 <= 0.009 , 0.0085 , 60.00, 2
> 0.009 <= 0.01 , 0.0095 , 65.00, 1
> 0.01 <= 0.011 , 0.0105 , 70.00, 1
> 0.012 <= 0.014 , 0.013 , 85.00, 3
> 0.016 <= 0.018 , 0.017 , 90.00, 1
> 0.018 <= 0.02 , 0.019 , 95.00, 1
> 0.02 <= 0.020018 , 0.020009 , 100.00, 1
# target 50% 0.008
# target 75% 0.0126667
# target 90% 0.018
# target 99% 0.0200144
# target 99.9% 0.0200176
Sockets used: 4 (for perfect keepalive, would be 2)
Code 200 : 18 (90.0 %)
Code 503 : 2 (10.0 %)
Response Header Sizes : count 20 avg 207.3 +/- 69.1 min 0 max 231 sum 4146
Response Body/Total Sizes : count 20 avg 603.3 +/- 123.2 min 217 max 645 sum 12066
All done 20 calls (plus 0 warmup) 9.789 ms avg, 193.6 qps
```

可以看到几乎所有请求都通过了

```
Code 200 : 18 (90.0 %)
Code 503 : 2 (10.0 %)
```

多次测试并发1-5

    root@128:/home/kinglong/istio# for i in `seq 1 10`;do kubectl exec -it $FORTIO_POD  -c fortio /usr/local/bin/fortio -- load -c $i -qps 0 -n 20 -loglevel Warning http://httpbin:8000/get|grep Code;echo '<<<<<<>>>>>>>';done
    Code 200 : 20 (100.0 %)
    <<<<<<>>>>>>>
    Code 200 : 17 (85.0 %)
    Code 503 : 3 (15.0 %)
    <<<<<<>>>>>>>
    Code 200 : 14 (70.0 %)
    Code 503 : 6 (30.0 %)
    <<<<<<>>>>>>>
    Code 200 : 9 (45.0 %)
    Code 503 : 11 (55.0 %)
    <<<<<<>>>>>>>
    Code 200 : 7 (35.0 %)
    Code 503 : 13 (65.0 %)
    <<<<<<>>>>>>>
    Code 200 : 7 (35.0 %)
    Code 503 : 13 (65.0 %)
    <<<<<<>>>>>>>
    Code 200 : 4 (20.0 %)
    Code 503 : 16 (80.0 %)
    <<<<<<>>>>>>>
    Code 200 : 8 (40.0 %)
    Code 503 : 12 (60.0 %)
    <<<<<<>>>>>>>
    Code 200 : 5 (25.0 %)
    Code 503 : 15 (75.0 %)
    <<<<<<>>>>>>>
    Code 200 : 3 (15.0 %)
    Code 503 : 17 (85.0 %)
    <<<<<<>>>>>>>

### ![](/assets/testCODEimport.png)

### 

### 清理现场

Remove the rules.

```
$ istioctl delete destinationrule httpbin
```

Shutdown the[httpbin](https://github.com/istio/istio/tree/release-0.8/samples/httpbin)service and client.

```
$ kubectl delete deploy httpbin fortio-deploy
$ kubectl delete svc httpbin
```



