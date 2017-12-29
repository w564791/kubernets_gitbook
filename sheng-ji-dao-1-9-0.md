升级步骤和1.8.6差不太多，这里只是写下一点区别就是了

1.kube-apiserver配置项目修改

`--experimental-bootstrap-token-auth ->  --enable-bootstrap-token-auth`

2.安装必要软件包

```
# apt install ipset
# apt install conntrack
```



