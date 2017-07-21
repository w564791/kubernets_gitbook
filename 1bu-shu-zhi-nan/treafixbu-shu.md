移步至下载地址:[点击下载](https://github.com/w564791/Kubernetes-Cluster/tree/master/yaml/treafix)

本处用到的yaml文件如下:

```
# ll .
-rw-r--r-- 1 root root 1210 Jul 21 09:36 traefik-ds.yaml
-rw-r--r-- 1 root root  379 Jul 21 09:36 traefix-ingress-rbac.yaml
-rw-r--r-- 1 root root  438 Jul 21 09:36 traefix-ingress.yaml
-rw-r--r-- 1 root root  261 Jul 21 09:36 traefix-svc.yaml
```



#### 直接运行

```
# kubectl create -f .
```

#### 查看信息

```
# kubectl get -f .
```

```
NAME                    DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE-SELECTOR   AGE
ds/traefik-ingress-lb   1         1         1         1            1           <none>          52m

NAME         SECRETS   AGE
sa/ingress   1         17h

NAME                          AGE
clusterrolebindings/ingress   17h

NAME                  HOSTS                                  ADDRESS   PORTS     AGE
ing/traefik-ingress   traefik.nginx.io,traefik.frontend.io             80        16h

NAME                 CLUSTER-IP     EXTERNAL-IP   PORT(S)           AGE
svc/traefik-web-ui   10.254.77.43   <none>        80/TCP,8580/TCP   17h

```



