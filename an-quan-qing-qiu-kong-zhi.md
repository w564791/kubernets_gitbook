### 在开始之前

* 需要正确部署istio
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序
* 运行一下命令创建sa,并且重新部署productpage

```
kubectl apply -f <(istioctl kube-inject -f samples/bookinfo/kube/bookinfo-add-serviceaccount.yaml)

```

### 使用拒绝访问控制

示例目标:

* details服务拒绝来自productpage的请求





