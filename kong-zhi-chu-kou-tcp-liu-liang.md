为了这个例子我们假设我们想要`wikipedia.org`通过域名访问。这意味着我们必须指定`wikipedia.org`TCP中的所有IP

`ServiceEntry`。IP地址在[这里](https://www.mediawiki.org/wiki/Wikipedia_Zero/IP_Addresses)`wikipedia.org`发布。它是[CIDR表示法](https://tools.ietf.org/html/rfc2317)中的IP块列表

创建`ServiceEntry`前访问该页面

```
# curl -o /dev/null -s -w "%{http_code}\n" https://www.wikipedia.org
000
```

## 创建服务条目 {#creating-a-service-entry}

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: wikipedia-ext
spec:
  hosts:
  - wikipedia.org
  addresses:
  - 91.198.174.192/27
  - 103.102.166.224/27
  - 198.35.26.96/27
  - 208.80.153.224/27
  - 208.80.154.224/27
  ports:
  - number: 443
    protocol: TCP
    name: tcp-port
  resolution: NONE
EOF
```

## 通过HTTPS访问wikipedia.org {#access-wikipedia-org-by-https}

提出请求并确认我们可以成功访问[https://www.wikipedia.org](https://www.wikipedia.org/)：

```
# curl -o /dev/null -s -w "%{http_code}\n" https://www.wikipedia.org
200
```

现在让我们用英语获取维基百科上可用的文章的当前数量

```
# curl -s https://en.wikipedia.org/wiki/Main_Page | grep articlecount | grep 'Special:Statistics'
<div id="articlecount" style="font-size:85%;"><a href="/wiki/Special:Statistics" title="Special:Statistics">5,666,674</a> articles in <a href="/wiki/English_language" title="English language">English</a></div>
```

### 代理HTTPS请求

```
cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: cnn
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 80
    name: http-port
    protocol: HTTP
  - number: 443
    name: http-port-for-tls-origination
    protocol: HTTP
  resolution: DNS
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: rewrite-port-for-edition-cnn-com
spec:
  hosts:
  - edition.cnn.com
  http:
  - match:
      - port: 80
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 443
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: originate-tls-for-edition-cnn-com
spec:
  host: edition.cnn.com
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    portLevelSettings:
    - port:
        number: 443
      tls:
        mode: SIMPLE # initiates HTTPS when accessing edition.cnn.com
EOF

```

这次我们收到_200 OK_作为第一个也是唯一的回应。Istio执行了TLS发起，`curl`因此原始HTTP请求以HTTPS的形式被转发到_cnn.com_。_cnn.com_的服务器直接返回内容，无需重定向。我们避免了客户端和服务器之间的双向往返，并且请求保留了网格的加密

。

