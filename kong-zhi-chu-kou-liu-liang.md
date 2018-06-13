以[http://www.baidu.com为例](http://www.baidu.com为例)

配置Egress之前

```
# curl --head www.baidu.com
HTTP/1.1 404 Not Found
date: Wed, 13 Jun 2018 09:02:12 GMT
server: envoy
content-length: 0
```

创建一个`ServiceEntry`允许访问外部HTTP服务：

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - www.baidu.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
EOF
```

再次尝试从pod内访问外部流量

```
# curl --head www.baidu.com
HTTP/1.1 200 OK
accept-ranges: bytes
cache-control: private, no-cache, no-store, proxy-revalidate, no-transform
content-length: 277
content-type: text/html
date: Wed, 13 Jun 2018 09:08:37 GMT
etag: "575e1f74-115"
last-modified: Mon, 13 Jun 2016 02:50:28 GMT
pragma: no-cache
server: envoy
x-envoy-upstream-service-time: 266
```

配置对外超时时间\(依赖之前的httpbin服务\)

```
cat <<EOF | istioctl replace -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-ext
spec:
  hosts:
  - httpbin.example.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
EOF
```

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-ext
spec:
  hosts:
    - ratings
  http:
  - timeout: 3s
    route:
      - destination:
          host: httpbin.example.com
        weight: 100
EOF
```

测试

```
# date +%s && curl http://httpbin.example.com/delay/2 && date +%s
1528882007
{
  "args": {},
  "data": "",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Content-Length": "0",
    "Host": "httpbin.example.com",
    "User-Agent": "curl/7.38.0",
    "X-B3-Parentspanid": "37a5510f8e8d3200",
    "X-B3-Sampled": "1",
    "X-B3-Spanid": "bf52c26f99ec3bf8",
    "X-B3-Traceid": "37a5510f8e8d3200",
    "X-Envoy-Expected-Rq-Timeout-Ms": "15000",
    "X-Envoy-Internal": "true",
    "X-Request-Id": "51ea6495-8367-9f55-997e-31a2f2e35a10"
  },
  "origin": "192.168.178.128",
  "url": "http://httpbin.example.com/delay/2"
}
1528882009
```

### 直接调用外部服务\(稍后翻译\)

## 了解发生了什么 {#understanding-what-happened}

在这个任务中，我们研究了两种从Istio网格调用外部服务的方法：

1. 使用`ServiceEntry`（推荐）

2. 配置Istio支架从重新映射的IP表中排除外部IP\(还没翻译\)

第一种方法（`ServiceEntry`）允许您使用所有相同的Istio服务网格特征来调用集群内外的服务。我们通过为外部服务调用设置超时规则来演示这一点。

第二种方法绕过Istio边车代理，让您的服务直接访问任何外部URL。

## 清理 {#cleanup}



