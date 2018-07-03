本次任务为Citadel启用kubernetes状态检查,请注意,这是Alpha功能.

默认情况下,istio部署的时候,CCitadel未启用健康检查功能,目前,健康检查功能通过定期向API发送CSR请求来检测Citadel的CSR签名鼓舞的故障,很快就会有更多的健康和检查功能

Citadel包含一个探针,可以定期检查Citadel的状态,如果Citadel是健康的,改探针客户端更新修改时间的健康状态文件\(该文件为空\),否则,其什么都不做,Citadel依靠K8S的liveness和readiness探针来检查的时间间隔和健康状态文件,如果文件未在一段时间内更新,则触发探测并重启Citadel容器

## 开始之前

启用全局MTLS

```
$ kubectl apply -f install/kubernetes/istio-demo-auth.yaml
```

或使用helm并修改global.mtls.enabled=true\(本例没有启用MTLS\)

部署检CItadel并启用健康检查

```
$ kubectl apply -f install/kubernetes/istio-citadel-with-health-check.yaml

```

确认Citadel已经部署service

```
$ kubectl get svc -n istio-system --selector=app=istio-citadel
istio-citadel   ClusterIP   10.254.239.137   <none>        8060/TCP,9093/TCP   3d

```

确认DNS能正确解析域名

```
# ping istio-citadel.istio-system
PING istio-citadel.istio-system.svc.cluster.local (10.254.239.137): 56 data bytes

```

验证健康检查工作内容

    # kubectl logs `kubectl get po -n istio-system | grep istio-citadel | awk '{print $1}'` -n istio-system


将看到如下输出:

```
...
2018-02-27T04:29:56.128081Z     info    CSR successfully signed.
...
2018-02-27T04:30:11.081791Z     info    CSR successfully signed.
...
2018-02-27T04:30:25.485315Z     info    CSR successfully signed.
...

```

### \(可选\)配置健康检查

```
...
  - --liveness-probe-path=/tmp/ca.liveness # path to the liveness health checking status file
  - --liveness-probe-interval=60s # interval for health checking file update
  - --probe-check-interval=15s    # interval for health status check
  - --logtostderr
  - --stderrthreshold
  - INFO
livenessProbe:
  exec:
    command:
    - /usr/local/bin/istio_ca
    - probe
    - --probe-path=/tmp/ca.liveness # path to the liveness health checking status file
    - --interval=125s               # the maximum time gap allowed between the file mtime and the current sys clock.
  initialDelaySeconds: 60
  periodSeconds: 60
...

```

liveness-probe-path 和probe-path均是指向健康检查状态文件,`liveness-probe-interval`是更新状态文件的间隔,如果Citadel是健康的.probe-check-interval是健康检查的间隔,interval是自上次健康检查以来经过的最长的时间

延长`probe-check-interval`间隔会减少一定的系统开销,但是对于不健康的通知,将会有一定的滞后,为了避免暂时的不可用而导致Citadel重启,interval可以配置为liveness-probe-interval的N倍以上

## 清理现场

清理健康检查

```
 kubectl  apply -f install/kubernetes/istio-demo.yaml


```



