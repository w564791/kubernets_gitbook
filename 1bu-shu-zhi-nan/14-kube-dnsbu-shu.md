#### [跳转至yaml下载地址](https://github.com/w564791/Kubernetes-Cluster/tree/master/yaml/DNS)

##### 使用到的镜像\(他人备份的镜像\):

```
index.tenxcloud.com/jimmy/k8s-dns-sidecar-amd64         1.14.1              fc5e302d8309        4 months ago        44.52 MB
index.tenxcloud.com/jimmy/k8s-dns-kube-dns-amd64        1.14.1              f8363dbf447b        4 months ago        52.36 MB
index.tenxcloud.com/jimmy/k8s-dns-dnsmasq-nanny-amd64   1.14.1              1091847716ec        4 months ago        44.84 MB
```

#### 第一步 创建ConfigMap

```
[root@k8s-1 kubedns]# cat kubedns-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
```

查看ConfigMap

```
# kubectl get -f kubedns-cm.yaml
NAME       DATA      AGE
kube-dns   0         2d
```

#### 第二步 创建ServiceAccount

```
[root@k8s-1 kubedns]# cat kubedns-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
```

查看sa

```
# kubectl get -f kubedns-sa.yaml
NAME       SECRETS   AGE
kube-dns   1         2d
```

#### 第三步 创建Service

```
[root@k8s-1 kubedns]# cat kubedns-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.254.0.2
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
```

查看svc

```
# kubectl get -f kubedns-svc.yaml
NAME       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   10.254.0.2   <none>        53/UDP,53/TCP   2d
```

* 将`--cluster-dns=10.254.0.2`选项添加到kubelet启动参数里,在启动的容器的`/etc/resolv.conf`便会自动加上如下内容:

```
#  kubectl exec busybox-rc-6xctm -n kube-system  -ti -- cat /etc/resolv.conf
nameserver 10.254.0.2
search kube-system.svc.cluster.local. svc.cluster.local. cluster.local. localdomain
options ndots:5
```

#### 第四部 创建RC\(重要\)

注意事项:

1.需要将`kubeconfig`文件挂载至容器内部,本文的此文件路径为`/etc/kubeconfig/config2`

```
#kubectl create cm kubeconfig --from-file=/root/.kube/config
```

3.`k8s-dns-kube-dns-amd64`容器启动时必须加`--kubecfg-file=/etc/kubernetes/config2`参数

--kubecfg-file 参数说明:

```
 --kubecfg-file string Location of kubecfg file for access to kubernetes master service; --kube-master-url overrides the URL part of this;if this is not provided, defaults to service account tokens
```

`[root@k8s-1 kubedns]# cat kubedns-controller.yaml`

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  # replicas: not specified here:
  # 1. In order to make Addon Manager do not reconcile this replicas parameter.
  # 2. Default is 1.
  # 3. Will be tuned in real time if DNS horizontal auto-scaling is turned on.
  strategy:
    rollingUpdate:
      maxSurge: 10%
      maxUnavailable: 0
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
      volumes:
      - hostPath:
         path: /etc/kubernetes  #提供挂载卷
        name: ssl-certs-kubernetess
      - hostPath:   #提供挂载文件
         path: /etc/hosts
        name: ssl-certs-hosts
      - name: kube-dns-config
        configMap:
          name: kube-dns
          optional: true
      containers:
      - name: kubedns
        image: index.tenxcloud.com/jimmy/k8s-dns-kube-dns-amd64:1.14.1
        imagePullPolicy: IfNotPresent
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        livenessProbe:
          httpGet:
            path: /healthcheck/kubedns
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 3
          timeoutSeconds: 5
        args:
        - --domain=cluster.local.
        - --dns-port=10053
        - --config-dir=/kube-dns-config
        - --v=2
        - --kubecfg-file=/etc/kubernetes/config2  ##配置启动参数,必须
        #__PILLAR__FEDERATIONS__DOMAIN__MAP__
        env:
        - name: PROMETHEUS_PORT
          value: "10055"
        ports:
        - containerPort: 10053
          name: dns-local
          protocol: UDP
        - containerPort: 10053
          name: dns-tcp-local
          protocol: TCP
        - containerPort: 10055
          name: metrics
          protocol: TCP
        volumeMounts:
        - name: kube-dns-config
          mountPath: /kube-dns-config
        - name: ssl-certs-kubernetess
          mountPath: /etc/kubernetes
          readOnly: true
        - name: ssl-certs-hosts
          mountPath: /etc/hosts
          readOnly: true


      - name: dnsmasq
        image: index.tenxcloud.com/jimmy/k8s-dns-dnsmasq-nanny-amd64:1.14.1
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /healthcheck/dnsmasq
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - -v=2
        - -logtostderr
        - -configDir=/etc/k8s/dns/dnsmasq-nanny
        - -restartDnsmasq=true
        - --
        - -k
        - --log-facility=-
        - --cache-size=1000
        - --server=/cluster.local./127.0.0.1#10053
        - --server=/in-addr.arpa/127.0.0.1#10053
        - --server=/ip6.arpa/127.0.0.1#10053
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        # see: https://github.com/kubernetes/kubernetes/issues/29055 for details
        resources:
          requests:
            cpu: 150m
            memory: 20Mi
        volumeMounts:
        - name: kube-dns-config
          mountPath: /etc/k8s/dns/dnsmasq-nanny
      - name: sidecar
        image: index.tenxcloud.com/jimmy/k8s-dns-sidecar-amd64:1.14.1
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /metrics
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - --v=2
        - --logtostderr
        - --probe=kubedns,127.0.0.1:10053,kubernetes.default.svc.cluster.local.,5,A
        - --probe=dnsmasq,127.0.0.1:53,kubernetes.default.svc.cluster.local.,5,A
        ports:
        - containerPort: 10054
          name: metrics
          protocol: TCP
        resources:
          requests:
            memory: 20Mi
            cpu: 10m
      dnsPolicy: Default  # Don't use cluster DNS.
      serviceAccountName: kube-dns  #这里是连接apiserver使用的账户
```

提供挂载卷

```
volumes:
- hostPath:
path: /etc/kubernetes #提供挂载卷
name: ssl-certs-kubernetess
- hostPath: #提供挂载文件
path: /etc/hosts
name: ssl-certs-hosts
```

* 挂载卷

```
volumeMounts:
- name: kube-dns-config
mountPath: /kube-dns-config
- name: ssl-certs-kubernetess
mountPath: /etc/kubernetes
readOnly: true
- name: ssl-certs-hosts
mountPath: /etc/hosts
readOnly: true
```

* 参数,必须要加上.否则会无法找到apiserver

```
image: index.tenxcloud.com/jimmy/k8s-dns-kube-dns-amd64:1.14.1
args:
- --kubecfg-file=/etc/kubernetes/config2
```

* `serviceAccountName: kube-dns` \#这里是连接`apiserver`使用的账户

查看deploy

```
# kubectl get -f kubedns-controller.yaml
NAME       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-dns   1         1         1            1           2d
```

last:效果图

![](/assets/nslookup.png)

##### 创建kubectl kubeconfig文件,此文件用于kubectl命令的 各项操作,

* 默认生成路径为~/.kube/config,_也可以用于dashboard,DNS的https认证,直接拷贝使用,我是直接拷贝到/etc/kubernetes/config2,然后挂载到容器里面作为dashboard的启动参数使用的. 如本文--kubecfg-file=/etc/kubernetes/config2_

```
export KUBE_APISERVER="https://k8s-1" 
# 设置集群参数 
# kubectl config set-cluster kubernetes \
--certificate-authority=/etc/kubernetes/ssl/ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
# 设置客户端认证参数
# kubectl config set-credentials admin \
--client-certificate=/etc/kubernetes/ssl/admin.pem \
--embed-certs=true \
--client-key=/etc/kubernetes/ssl/admin-key.pem
# 设置上下文参数
# kubectl config set-context kubernetes \
--cluster=kubernetes \
--user=admin
# 设置默认上下文
kubectl config use-context kubernetes
```

查看生成的文件格式:

```
# cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ...
    server: https://k8s-1
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: admin
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate-data: ...
    client-key-data: ...
```



