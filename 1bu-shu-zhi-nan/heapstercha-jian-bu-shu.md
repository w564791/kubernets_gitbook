本处使用到的yaml文件,[跳转下载](https://github.com/w564791/Kubernetes-Cluster/tree/master/heapster)

## 配置 grafana-deployment

* heapster的grafana不需要了，后面部署Prometheus也会用Prometheus

## 执行所有文件

```
# kubectl create -f .
```

```
# kubectl get -f .
```

```

NAME              DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/heapster   1         1         1            1           16h

NAME          SECRETS   AGE
sa/heapster   1         16h

NAME                           AGE
clusterrolebindings/heapster   16h

NAME           CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
svc/heapster   10.254.121.179   <none>        80/TCP    16h

NAME                 DATA      AGE
cm/influxdb-config   1         16h

NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deploy/monitoring-influxdb   1         1         1            1           16h

NAME                      CLUSTER-IP     EXTERNAL-IP   PORT(S)                         AGE
svc/monitoring-influxdb   10.254.61.66   <nodes>       8086:31086/TCP,8083:31083/TCP   16h
```

```
# kubectl  get pods -n kube-system |grep -E "heapster|monitor"
```

```
heapster-290061577-5kj1r               1/1       Running   0          16h
monitoring-grafana-1581303656-9w0nb    1/1       Running   0          16h
monitoring-influxdb-2399066898-sld2p   1/1       Running   0          16h
```

## 通过apiserver访问dashboard

```
https://192.168.103.143/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard/
```

## ![](/assets/dashboard-deploy.png)![](/assets/dashboard-pod.png)通过apiserver访问grafana-dashboard（后面使用Prometheus）

```
https://192.168.103.143/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana
```



