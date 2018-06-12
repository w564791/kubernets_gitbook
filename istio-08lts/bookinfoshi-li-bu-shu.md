![](/assets/bookinfo-gateway.yaml)下载相应文件

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

确认bookinfo应用完全启动





