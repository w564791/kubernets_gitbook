### 手动注入

手动注入sidecar,主要有2种方式,默认的是从configMap种拉去配置,`injectConfig: istio-sidecar-injector`以及`meshConfig: istio`

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
    --filename samples/sleep/sleep.yaml |kubectl apply  -f -
```

### 自动注入

自动注入需要K8S集群1.9以上,开启`MutatingAdmissionWebhook`和`ValidatingAdmissionWebhook,`在kube-apiserver配置--enable-admission-plugins字段增加`MutatingAdmissionWebhook,ValidatingAdmissionWebhook`参数,然后部署istio

```
$ kubectl create ns istio-system
$ kubectl apply -n istio-system -f istio.yaml
```

当命名空间有istio-injection=enabled的label的时候,部署项目时会自动注入sidecar,删除label时,自动注入sidecar失效,正在运行的项目且部署有sidecar,不会重建,pod重启时,会自动剔除sidecar

