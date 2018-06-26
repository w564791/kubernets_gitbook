### 开始之前

* 部署istio服务

* [部署bookinfo示例](https://istio.io/docs/guides/bookinfo/)

将所有的流量导向v3,Jason用户的流量导向v2

```
# istioctl create -f samples/bookinfo/routing/route-rule-all-v1.yaml



```



