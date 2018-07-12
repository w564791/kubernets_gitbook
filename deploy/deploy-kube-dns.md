下载CoreDNS官方部署文件

```
git clone https://github.com/coredns/deployment.git
```

使用官方提供的部署脚本直接部署

```
 # cd deployment/kubernetes/
 # ./deploy.sh  -i 10.254.0.2|kubectl create -f -
```

