### 手动注入

手动注入sidecar,主要有2种方式,默认的是从configMap种拉去配置,`injectConfig: istio-sidecar-injector `以及`meshConfig: istio`

当然也可以从文件中读取配置,从configMap中拉去配置并保存在文件中

```
kubectl -n istio-system get configmap istio-sidecar-injector -o=jsonpath='{.data.config}' > inject-config.yaml
kubectl -n istio-system get configmap istio -o=jsonpath='{.data.mesh}' > mesh-config.yaml
```

使用配置文件创建项目

```
istioctl kube-inject \
    --injectConfigFile inject-config.yaml \
    --meshConfigFile mesh-config.yaml \
    --filename samples/sleep/sleep.yaml |kubectl create -f -

```



