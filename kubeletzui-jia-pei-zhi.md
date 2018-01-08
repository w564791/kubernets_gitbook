_https://my.oschina.net/jxcdwangtao/blog/891960_

**kubernetes version: 1.6.2**

## Kubelet Configurations We Should Care About {#h2_0}

下面是我梳理的，我认为必须关注的flag。

| flag | value |
| :--- | :--- |
| --address | 0.0.0.0 |
| **--allow-privileged** | false |
| --cadvisor-port int32 | 4194 |
| --cgroup-driver string | cgroupfs |
| --cluster-dns stringSlice | 10.0.0.10 //todo |
| --cluster-domain string | caas.vivo.com |
| --cni-bin-dir string | /opt/cni/bin |
| --cni-conf-dir string | /etc/cni/net.d |
| --docker-endpoint string | [unix:///var/run/docker.sock](unix:///var/run/docker.sock) |
| **--eviction-hard**string | memory.available&lt;4Gi,&lt;br/&gt; nodefs.available&lt;20Gi,&lt;br/&gt; imagefs.available&lt;5Gi |
| **--eviction-max-pod-grace-period**int32 | 30 |
| **--eviction-minimum-reclaim**string | memory.available=500Mi,&lt;br/&gt; nodefs.available=2Gi,,&lt;br/&gt; imagefs.available=2Gi |
| **--eviction-pressure-transition-period**duration | 5m0s |
| **--eviction-soft string** | memory.available&lt;8Gi,&lt;br/&gt; nodefs.available&lt;100Gi,&lt;br/&gt; imagefs.available&lt;20Gi |
| **--eviction-soft-grace-period**string | memory.available=30s,&lt;br/&gt; nodefs.available=2m,&lt;br/&gt; imagefs.available=2m |
| **--experimental-fail-swap-on** | + |
| **--experimental-kernel-memcg-notification** | + |
| --feature-gates string | AllAlpha=false |
| **--file-check-frequency**duration | 20s |
| --hairpin-mode string | promiscuous-bridge |
| --healthz-port int32 | 10248 |
| **--image-gc-high-threshold**int32 | 60 |
| **--image-gc-low-threshold**int32 | 40 |
| --image-pull-progress-deadline duration | 2m0s |
| --kube-api-qps int32 | 5 |
| --kube-reserved mapStringString | cpu=200m,memory=16G |
| **--kubeconfig**string | /var/lib/kubelet/kubeconfig |
| --max-pods int32 | 50 |
| --minimum-image-ttl-duration duration | 1h |
| **--network-plugin**string | cni |
| **--pod-infra-container-image**string | vivo.registry.com/google\_containers/pause-amd64:3.0 |
| **--pod-manifest-path**string | /var/lib/kubelet/pod\_manifest |
| --port int32 | 10250 |
| **--protect-kernel-defaults** | + |
| --read-only-port int32 | 10255 |
| **--require-kubeconfig** | + |
| --root-dir string | /var/lib/kubelet |
| --runtime-request-timeout duration | 2m0s |
| --serialize-image-pulls | false |
| --sync-frequency duration | 1m0s |
| --system-reserved mapStringString | cpu=100m,memory=32G |
| --volume-plugin-dir string | /usr/libexec/kubernetes/kubelet-plugins/volume/exec/ |
| --volume-stats-agg-period duration | 1m0s |

## Kubelet Configuration Best Practicies {#h2_1}

下面是我最终梳理的，认为需要真正显示设置的flag，如下：

```
/usr/bin/kubelet —address=0.0.0.0 
--port=10250 
--allow-privileged=false 
--cluster-dns=10.0.0.1 
--cluster-domain=caas.vivo.com
--max-pods=50 
--network-plugin=cni 
--require-kubeconfig 
--pod-manifest-path=/etc/kubelet.d/
--pod-infra-container-image=vivo.registry.com/google_containers/pause-amd64:3.0 
--eviction-hard=memory.available<4Gi,nodefs.available<20Gi,imagefs.available<5Gi 
--eviction-max-pod-grace-period=30 
--eviction-minimum-reclaim=memory.available=500Mi,nodefs.available=2Gi,imagefs.available=2Gi 
--eviction-pressure-transition-period=5m0s 
--eviction-soft=memory.available<8Gi,nodefs.available<100Gi,imagefs.available<20Gi 
--eviction-soft-grace-period=memory.available=30s,nodefs.available=2m,imagefs.available=2m 
--experimental-kernel-memcg-notification 
--experimental-fail-swap-on 
--system-reserved=cpu=100m,memory=8G 
--kube-reserved=cpu=200m,memory=16G
--hairpin-mode=promiscuous-bridge 
--image-gc-high-threshold=60 
--image-gc-low-threshold=40 
--serialize-image-pulls=false 
--protect-kernel-defaults 
--feature-gates=AllAlpha=false 
```

  


