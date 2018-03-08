[yaml文件下载](https://github.com/w564791/Kubernetes-Cluster/tree/master/prometheus-kubernetes)

### kubernetes-prometheus

> 部署prometheus到kubernetes到模板，提取自[prometheus-operator](https://github.com/coreos/prometheus-operator)，需要先配置好DefaultStorageClass。
>
> pre 创建namespace
>
> ```
> kubectl create ns monitoring
>
> ```

1. 部署prometheus:

   ```
   kubectl create -f prometheus-rbac.yaml
   kubectl create -f prometheus-k8s-cm.yaml
   kubectl create -f prometheus-k8s-rules.yaml
   kubectl create -f prometheus-statefulset.yaml
   kubectl create -f prometheus-svc.yaml

   ```

2. 部署alertmanager（alertmanager主要用来做prometheus的监控告警）：

   ```
   kubectl create -f alertmanager-cm.yaml
   kubectl create -f alertmanager-statefulset.yaml
   kubectl create -f alertmanager-svc.yaml

   ```

3. 部署kube-state-metric（kube-state-metric用来获取k8s集群的关联信息）:

   ```
   kubectl create -f kube-state-metric-rbac.yaml
   kubectl create -f kube-state-metric-deploy.yaml
   kubectl create -f kube-state-metric-svc.yaml

   ```

4. 部署node-exporter（如果需要宿主机的监控，需要部署node-exporter）：

   ```
   kubectl create -f node-exporter-ds.yaml
   kubectl create -f node-exporter-svc.yaml

   ```

5. 部署grafana（grafana用来做监控的绘图展示）,PS:需要替换grafana里的账户密码

   ```
   kubectl create -f grafana-credentails.secret.yaml
   kubectl create -f grafana-deploy.yaml
   kubectl create -f grafana-svc.yaml

   ```

6. 建相关enpoints用于kubelet、kube-conrtroller-manger、kube-scheduler、etcd等的监控：

   ```
   kubectl create -f prometheus-discovery-service.yaml

   ```

7. 创建dashboard的configmap

   ```
   kubectl create -f dashboard.yaml

   ```

8. 创建导入dashboard的job

   ```
   kubectl create -f grafana-import-dashboards-job.yaml

   ```

9. 创建钉钉报警webhook,PS:需要替换掉钉钉的token

   ```
   kubectl create -f dingtalk.yaml

   ```

10. grafana默认登录账户密码 admin admin



