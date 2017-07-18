#### [跳转至yaml下载链接 ](https://github.com/w564791/Kubernetes-Cluster/tree/master/yaml/dashboard-tls)

##### 使用到的镜像\(他人备份的镜像\):

```
index.tenxcloud.com/jimmy/kubernetes-dashboard-amd64    v1.6.0              416701f962f2        4 months ago        108.6 MB
```

#### 第一步 创建RBRC授权,必须要第一步创建,不然容器也起不来,后面创建也可以,没毛病

```
[root@k8s-1 dashboard]# cat rbac.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: dashboard
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: dashboard
  labels:
    k8s-app: dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dashboard
subjects:
- kind: ServiceAccount
  name: dashboard
  #定义一个名为dashboard的ServiceAccount,然后和ClusterRole绑定,否则报错如下"ERROR-001"
  namespace: kube-system
```

##### "ERROR-001":

```
"kube-system/kubernetes-dashboard-2689983591" failed with unable to create pods: pods "kubernetes-dashboard-2689983591-" is forbidden: service account kube-system/dashboard was not found, retry after the service account is created
```

#### 第二步 创建service

```
[root@k8s-1 dashboard]# cat dashboard-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  type: NodePort
  selector:
    k8s-app: kubernetes-dashboard
  ports:
  - port: 80
    targetPort: 9090
    nodePort: 31100
```

#### 第三步 创建dashboard-Deployment

参考: [https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml](https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml)

注意事项:

1.需要将kubeconfig文件挂载至容器内部,本文的此文件路径为/etc/kubeconfig/config2

2.需要将/etc/hosts挂载到容器内部.因为apiserver认证时不能用IP\(证书里面没写IP\)

3.容器启动时必须加--kubeconfig=/etc/kubernetes/config2参数

--kubeconfig 参数说明:

```
--kubeconfig string                Path to kubeconfig file with authorization and master location information.
```

---

```
[root@k8s-1 dashboard]# cat dashboard-controller.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      volumes:
      - hostPath:
         path: /etc/kubernetes
        name: ssl-certs-kubernetess
        #将宿主机的目录映射为卷,随便哪个路径都行,只要路径里面包含了config2文件都行
      - hostPath:
         path: /etc/hosts
        name: ssl-certs-hosts
        #将hosts文件映射到容器内,否则可能会找不到apiserver的地址
      serviceAccountName: dashboard   #前文创建的serveraccount及这个
      containers:
      - name: kubernetes-dashboard
        image: index.tenxcloud.com/jimmy/kubernetes-dashboard-amd64:v1.6.0
        imagePullPolicy: IfNotPresent
        args:
         - --kubeconfig=/etc/kubernetes/config2
         #最坑的就是这个了,网上很多抄袭的文章,连启动参数都没有,真不知道是咋启动的,以前用http的时候使用的--apiserver-host参数,此处因为使用了https,所以改用--kubeconfig参数,这个文件的生成方式见后文"METHOD001"
        volumeMounts:
         - mountPath: /etc/kubernetes
           name: ssl-certs-kubernetess
           readOnly: true
           #挂载卷
         - mountPath: /etc/hosts
           name: ssl-certs-hosts
           readOnly: true
           #挂载hosts
        resources:
          limits:
            cpu: 100m
            memory: 50Mi
          requests:
            cpu: 100m
            memory: 50Mi
        ports:
        - containerPort: 9090
        livenessProbe:
          httpGet:
            path: /
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
```

##### 将证书导出,装在client浏览器上

```
openssl pkcs12 -export -in admin.pem -inkey admin-key.pem -out /etc/kubernetes/web-cret.p12
```

##### 创建kubectl kubeconfig文件,此文件用于kubectl 各项操作,

* 默认生成路径为~/.kube/config,也可以用于dashboard,DNS的https认证,直接拷贝使用,我是直接拷贝到/etc/kubernetes/config2,然后挂载到容器里面作为dashboard的启动参数使用的. 如本文 --kubeconfig=/etc/kubernetes/config2

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

##### 通过loadbalancer访问dashboard

备注:因为apiserver和容器之间不可达,所以需要添加一条路由信息;

```
route add -net 10.1.34.0/24 gw 192.168.103.143
```

192.168.103.143是dashboard所在的node\(我是单节点测试\),也是loadbalancer的复用机器

[https://loadbalancer/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard](https://apiserver:6443/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard)

![](/assets/lb-dashboard.png)

来看看我们创建的几个pods

![](/assets/pods-all.png)

