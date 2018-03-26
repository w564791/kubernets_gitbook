编辑中。。。

本例中网络组件使用flanneld，不再使用kube-router提供的pod-to-pod网络

```
Kube-router is built around concept of watchers and controllers. Watchers use Kubernetes watch API to get notification on events related to create, update, delete of Kubernetes objects. Each watcher gets notification related to a particular API object. On receiving an event from API server, watcher broadcasts events. Controller registers to get event updates from the watchers and act up on the events.
```

* kube-router 的核心概念是其watchers和controllers，watchers通过监控K8S的api变化，create，update，delete K8S对象，每个watcher都会获取特定的api对象相关的通知，当从API接受到事件后，watchers广播事件，controller对事件进行更新并处理

Kube-router由3个核心控制器和多个观察器组成，如下图所示：

![](/assets/kube-router.png)

在kubernetes集群中部署kube-router（支持nodePort）

```
# cat kube-router.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-router-cfg
  namespace: kube-system
  labels:
    tier: node
    k8s-app: kube-router
data:
  10-kuberouter.conflist: |
    {
       "cniVersion":"0.3.0",
       "name":"mynet",
       "plugins":[
          {
             "name":"kubernetes",
             "type":"bridge",
             "bridge":"kube-bridge",
             "isDefaultGateway":true,
             "ipam":{
                "type":"host-local"
             }
          },
          {
             "type":"portmap",
             "capabilities":{
                "snat":true,
                "portMappings":true
             }
          }
       ]
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-router
  namespace: kube-system
  labels:
    k8s-app: kube-router
spec:
  template:
    metadata:
      labels:
        k8s-app: kube-router
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      containers:
      - name: kube-router
        image: cloudnativelabs/kube-router
        args: ["--run-router=false", "--run-firewall=false", "--run-service-proxy=true", "--kubeconfig=/var/lib/kube-router/kubeconfig", "--masquerade-all", "--ipvs-sync-period=5s", "--iptables-sync-period=10s","--cluster-cidr=10.20.0.0/16","--metrics-port=80"]
        securityContext:
          privileged: true
        imagePullPolicy: Always
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: KUBE_ROUTER_CNI_CONF_FILE 
          value: /etc/cni/net.d/10-kuberouter.conflist
        volumeMounts:
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        - name: cni-conf-dir
          mountPath: /etc/kubernetes/cni/net.d
        - name: kubeconfig
          mountPath: /var/lib/kube-router/kubeconfig
          readOnly: true
        - name: cert
          mountPath: /etc/kubernetes/ssl
        - name: kube-router-cfg
          mountPath: /etc/cni/net.d/
      hostNetwork: true
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: cni-conf-dir
        hostPath:
          path: /etc/kubernetes/cni/net.d
      - name: kube-router-cfg
        configMap:
          name: kube-router-cfg
      - name: kubeconfig
        hostPath:
          path: /etc/kubernetes/kubeconfig
      - name: cert
        hostPath:
          path: /etc/kubernetes/ssl
```

```
kubectl create -f kube-router.yaml
```

修改代理方式：默认为轮询rr

```
使用最少连接：
kubectl patch svc go-cloudmsg -p '{"metadata":{"annotations":{"kube-router.io/service.scheduler":"lc"}}}'
使用轮询
kubectl patch svc go-cloudmsg -p '{"metadata":{"annotations":{"kube-router.io/service.scheduler":"rr"}}}'
使用来源地址哈希
kubectl patch svc go-cloudmsg -p '{"metadata":{"annotations":{"kube-router.io/service.scheduler":"sh"}}}'
使用目标地址哈希
kubectl patch svc go-cloudmsg -p '{"metadata":{"annotations":{"kube-router.io/service.scheduler":"dh"}}}'
```

修改默认网络策略为拒绝（例子里没有使用网络策略，可以忽略）

```
kubectl annotate ns production "net.beta.kubernetes.io/network-policy={\"ingress\": {\"isolation\": \"DefaultDeny\"}}"
```

更改策略（可以忽略）：

```
apiVersion: extensions/v1beta1                                                                                                                                                                              
kind: NetworkPolicy                                                                                                                                                                                         
metadata:                                                                                                                                                                                                   
 name: guestbook-allow-frontend                                                                                                                                                                             
spec:                                                                                                                                                                                                       
 podSelector:                                                                                                                                                                                               
  matchLabels:                                                                                                                                                                                              
    tier: frontend                                                                                                                                                                                          
 ingress:                                                                                                                                                                                                   
  - from:                                                                                                                                                                                                   
    ports:                                                                                                                                                                                                  
     - protocol: TCP                                                                                                                                                                                        
       port: 80                                                                                                                                                                                             
---                                                                                                                                                                                                         
apiVersion: extensions/v1beta1                                                                                                                                                                              
kind: NetworkPolicy                                                                                                                                                                                         
metadata:                                                                                                                                                                                                   
 name: guestbook-allow-backend                                                                                                                                                                              
spec:                                                                                                                                                                                                       
 podSelector:                                                                                                                                                                                               
  matchLabels:                                                                                                                                                                                              
    tier: backend                                                                                                                                                                                           
 ingress:                                                                                                                                                                                                   
  - from:                                                                                                                                                                                                   
     - podSelector:                                                                                                                                                                                         
        matchLabels:                                                                                                                                                                                        
          tier: frontend                                                                                                                                                                                    
          app: guestbook                                                                                                                                                                                    
    ports:                                                                                                                                                                                                  
     - protocol: TCP                                                                                                                                                                                        
       port: 6379
```



