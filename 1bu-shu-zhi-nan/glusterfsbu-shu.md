## PRE：每台机器上需要准备一个块存储设备

本例有3个节点



* 192.168.70.175 /dev/sdc
* 192.168.70.170 /dev/sdc

* 192.168.70.171 /dev/sdc

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

## 4.创建namespace（方便失败后重试）

```
root@node1:~/gluster-kubernetes3/deploy# kubectl create ns storage
```



