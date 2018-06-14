下载地址

```
wget https://github.com/istio/istio/releases/download/0.8.0/istio-0.8.0-linux.tar.gz
```

安装

```
#kubectl create -f  istio-0.8.0/install/kubernetes/istio-demo.yaml
```

确认安装

```
# kubectl get po -n istio-system
NAME                                       READY     STATUS      RESTARTS   AGE
grafana-6f6dff9986-kc57q                   1/1       Running     2          1d
istio-citadel-7bdc7775c7-f6ckv             1/1       Running     2          1d
istio-cleanup-old-ca-knv47                 0/1       Completed   0          1d
istio-egressgateway-795fc9b47-pp2fk        1/1       Running     4          1d
istio-ingressgateway-7d89dbf85f-2tggh      1/1       Running     4          1d
istio-mixer-post-install-rsv8h             0/1       Completed   0          1d
istio-pilot-66f4dd866c-jc5fd               2/2       Running     4          1d
istio-policy-76c8896799-fr7jj              2/2       Running     4          1d
istio-sidecar-injector-645c89bc64-xrnlg    1/1       Running     9          1d
istio-statsd-prom-bridge-949999c4c-v848n   1/1       Running     2          1d
istio-telemetry-6554768879-k7tff           2/2       Running     4          1d
istio-tracing-754cdfd695-hb77x             1/1       Running     1          1d
prometheus-86cb6dd77c-gsl9f                1/1       Running     3          1d
servicegraph-5849b7d696-djj8t              1/1       Running     7          1d
```

修改ingressgateway暴露方式为nodePort,默认不会启动80,443端口,当gateway创建时,80,443才会启动

```
istio-ingressgateway       NodePort    10.254.150.79    <none>        80:80/TCP,443:443/TCP,31400:31400/TCP
```



