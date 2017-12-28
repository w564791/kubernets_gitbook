#### PRE：每台机器上需要准备一个块存储设备

本例有3个节点

* 192.168.70.175 /dev/sdc
* 192.168.70.170 /dev/sdc
* 192.168.70.171 /dev/sdc

所有node上需要安装glusterfs-client包，否则会报`unkown glusterfs filesystem`

需要安装相应的modules

* dm\_snap
* dm\_mirror
* dm\_thin\_pool

## 1.在GitHub上clono项目

```
git clone https://github.com/gluster/gluster-kubernetes.git
```

## 2.下载heketi-cli

```
#wget https://github.com/heketi/heketi/releases/download/v4.0.0/heketi-client-v4.0.0.linux.amd64.tar.gz
#tar -xvf heketi-client-v4.0.0.linux.amd64.tar.gz
#cp heketi-client/bin/heketi-cli /bin/
```

## 3.修改topology模板

```
root@node1:~/gluster-kubernetes3/deploy# cat topology.json
{
  "clusters": [
    {
      "nodes": [
        {
          "node": {
            "hostnames": {
              "manage": [
                "192.168.70.175"
              ],
              "storage": [
                "192.168.70.175"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdc"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "192.168.70.171"
              ],
              "storage": [
                "192.168.70.171"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdc"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "192.168.70.170"
              ],
              "storage": [
                "192.168.70.170"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/sdc"
          ]
        }
      ]
    }
  ]
}
```

## 4.创建namespace（方便失败后重试，直接删除ns即可）

```
root@node1:~/gluster-kubernetes3/deploy# kubectl create ns storage
```

## 5.开始部署

```
root@node1:~/gluster-kubernetes3/deploy# ./gk-deploy -g -n storage
```

成功后提示

```
heketi is now running and accessible via http://172.16.43.4:8080 . To run
administrative commands you can install 'heketi-cli' and use it as follows:

  # heketi-cli -s http://172.16.43.4:8080 --user admin --secret '<ADMIN_KEY>' cluster list

You can find it at https://github.com/heketi/heketi/releases . Alternatively,
use it from within the heketi pod:

  # /bin/kubectl -n default exec -i <HEKETI_POD> -- heketi-cli -s http://localhost:8080 --user admin --secret '<ADMIN_KEY>' cluster list

For dynamic provisioning, create a StorageClass similar to this:

---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: glusterfs-storage
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://172.16.43.4:8080"


Deployment complete!
```

## 6.失败后重试

1. 删除vg
2. 删除pv
3. 删除nnamespace
4. rm -rf /var/lib/heket  /var/lib/glusterd
5. 删除clusterrolebindings

## 7.创建storage class

查看heketi的ClusterIP地址，storage class里似乎无法用域名通信，抛错

```
root@node1:~/gluster-kubernetes3/deploy/kube-templates# kubectl get svc/heketi --template 'http://{{.spec.clusterIP}}:{{(index .spec.ports 0).port}}'
http://10.254.112.16:8080
```

复制上面的地址到storage class的yaml文件

```
root@node1:~/gluster-kubernetes3/deploy/kube-templates# cat gluster-s3-storageclass.yaml 
---
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: gluster-heketi
provisioner: kubernetes.io/glusterfs
parameters:
    resturl: "http://10.254.112.16:8080"
```

创建storage class

```
kubectl create -f gluster-s3-storageclass.yaml
```

## 8.在Prometheus测试

[Prometheus部署](/1bu-shu-zhi-nan/prometheusbu-shu.md)

