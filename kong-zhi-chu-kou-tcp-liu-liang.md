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



