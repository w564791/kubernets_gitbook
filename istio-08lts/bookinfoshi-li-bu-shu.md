下载相应文件

```
wget https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/kube/bookinfo.yaml
wget https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/bookinfo-gateway.yaml
wget https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/route-rule-all-v1.yaml
wget https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/route-rule-reviews-test-v2.yaml
```

创建bookinfo应用

```
istioctl  kube-inject -f bookinfo.yaml |kubectl  create -f -
```

bookinfo架构

![](/assets/bookinfoimport.png)

The Bookinfo application is broken into four separate microservices:



productpage. productpage microservice调用details 和reviews来填充页面

details. 包含书籍信息。.

reviews. 评论微服务.

ratings. 该服务随reviews一起包含书籍排行信息.

有3个版本的reviews微服务:



Version v1 doesn’t call the ratings service.

Version v2 calls the ratings service, and displays each rating as 1 to 5 black stars.

Version v3 calls the ratings service, and displays each rating as 1 to 5 red stars.

确认bookinfo应用完全启动

[route-rule-reviews-test-v2.yaml](https://github.com/w564791/kubernets_gitbook/blob/master/assets/route-rule-reviews-test-v2.yaml)

[route-rule-all-v1.yaml](https://github.com/w564791/kubernets_gitbook/blob/master/assets/route-rule-all-v1.yaml)

[bookinfo-gateway.yaml](https://github.com/w564791/kubernets_gitbook/blob/master/assets/bookinfo-gateway.yaml)

[bookinfo.yaml](https://github.com/w564791/kubernets_gitbook/blob/master/assets/bookinfo.yaml)

