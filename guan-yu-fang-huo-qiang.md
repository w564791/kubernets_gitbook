## Table 1. Node to Node

| **4789** | UDP | Required for SDN communication between pods on separate hosts. |
| :--- | :--- | :--- |


## Table 2. Nodes to Master

| **53**or**8053** | TCP/UDP | Required for DNS resolution of cluster services \(SkyDNS\). Installations prior to 1.2 or environments upgraded to 1.2 use port 53. New installations will use 8053 by default so that**dnsmasq**may be configured. |
| :--- | :--- | :--- |
| **4789** | UDP | Required for SDN communication between pods on separate hosts. |
| **443**or**6443** | TCP | Required for node hosts to communicate to the master API, for the node hosts to post back status, to receive tasks, and so on. |

## Table 3. Master to Node

| **4789** | UDP | Required for SDN communication between pods on separate hosts. |
| :--- | :--- | :--- |
| **10250** | TCP | The master proxies to node hosts via the Kubelet for`oc`commands. |

## Table 4. Master to Master

| **53 \(L\)**or**8053 \(L\)** | TCP/UDP | Required for DNS resolution of cluster services \(SkyDNS\). Installations prior to 1.2 or environments upgraded to 1.2 use port 53. New installations will use 8053 by default so that**dnsmasq**may be configured. |
| :--- | :--- | :--- |
| **2049 \(L\)** | TCP/UDP | Required when provisioning an NFS host as part of the installer. |
| **2379** | TCP | Used for standalone etcd \(clustered\) to accept changes in state. |
| **2380** | TCP | etcd requires this port be open between masters for leader election and peering connections when using standalone etcd \(clustered\). |
| **4001 \(L\)** | TCP | Used for embedded etcd \(non-clustered\) to accept changes in state. |
| **4789 \(L\)** | UDP | Required for SDN communication between pods on separate hosts. |



firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="10.1.0.0/16"   accept"

firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="10.254.0.0/16"   accept"

参考资料

\[1\] [https://docs.openshift.org/1.5/install\_config/install/prerequisites.html](https://docs.openshift.org/1.5/install_config/install/prerequisites.html)

