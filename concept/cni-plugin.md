FROM https://www.lijiaocn.com/%E9%A1%B9%E7%9B%AE/2017/08/04/calico-arch.html

cni-plugin会在指定的network ns中创建veth pair。

位于容器中的veth，将被设置ip，并设置169.254.1.1为默认路由，在容器内可以看到:

```
$ip route
default via 169.254.1.1 dev eth0
169.254.1.1 dev eth0  scope link
```

因为169.254.1.1是无效IP，因此，cni-plugin还要在容器内设置一条静态arp: (2021-4-27更正:静态arp 的mac地址在所有容器内都是ee:ee:ee:ee:ee:ee)

```
$ip neighbor
169.254.1.1 dev eth0 lladdr ea:88:97:5f:06:d9 STALE
```

169.254.1.1的mac地址被设置为了veth设备在host中的一端mac地址，容器中所有的报文就会发送到了veth的host端。

cni-plugin创建了endpoint之后，会将其保存到etcd中，felix从而感知到endpoint的变化。

之后，felix会在host端设置一条静态arp:

```
192.168.8.42 dev cali69de609d5af lladdr b2:21:5b:82:e1:27 PERMANENT
```

这样在host上就可以访问容器的地址。

### [CentOS7] 使用ip neighbor指令来侦测修改其他的节点 FROM https://n.sfs.tw/content/index/11049?noframe=true

### 查看其他的节点

```
# ip ne
192.168.3.132 dev eth0 lladdr ee:ff:ff:ff:ff:ff REACHABLE
192.168.3.124 dev eth0 lladdr ee:ff:ff:ff:ff:ff REACHABLE
172.30.6.0 dev flannel.1 lladdr ca:82:f5:77:60:38 PERMANENT
172.30.45.4 dev docker0  FAILED
172.30.91.0 dev flannel.1 lladdr c2:75:cd:6c:e8:6a PERMANENT
192.168.3.125 dev eth0 lladdr ee:ff:ff:ff:ff:ff REACHABLE
192.168.3.134 dev eth0 lladdr ee:ff:ff:ff:ff:ff STALE
172.30.45.2 dev docker0 lladdr 02:42:ac:1e:2d:02 REACHABLE
192.168.3.126 dev eth0 lladdr ee:ff:ff:ff:ff:ff REACHABLE
172.30.54.0 dev flannel.1 lladdr 76:c5:14:6a:e5:8c PERMANENT
172.30.96.0 dev flannel.1 lladdr 56:6b:51:72:d9:56 PERMANENT
172.30.45.3 dev docker0 lladdr 02:42:ac:1e:2d:03 STALE
192.168.3.135 dev eth0 lladdr ee:ff:ff:ff:ff:ff STALE
192.168.3.127 dev eth0 lladdr ee:ff:ff:ff:ff:ff STALE
192.168.3.253 dev eth0 lladdr ee:ff:ff:ff:ff:ff REACHABLE

```

其中ne是neighbor的懒惰写法，也可以更懒写成ip n，其显示结果为 

        1 **IP/IP6位址** 2 **dev**   **网卡id**  3  **lladdr** 这个设备二层地址(MAC) 4 **router** 5 **状态**

1. IP4或IP6位址，如果fe80开头的IP6位址，代表那是link-local的IP6位址。

2. dev+介面卡的id，可由指令ip addr 来查看，特别注意的是不会出现本机的位址，因为这显示的是邻居节点。

3. lladdr+MAC位址，lladdr是link-layer address的缩写，如果状态是FAILED此栏不会出现。

4. 如果是IPv6的router会出现这个字，否则不会出现

5. 状态，会出现的状态主要有几种，代表的意义如下，以下内容是我研究过并不是翻译文：

   	

   | 状态       | 解释                                                         |
   | ---------- | ------------------------------------------------------------ |
   | REACHABLE  | 邻居节点回应了NA的封包表示已收到NS封包，节点可达性确认       |
   | STALE      | (过期)自从上次邻居可达性状态后过了*ReachableTime*之后都没有再和此节点连系过。*ReachableTime*预设会是随机15~45之间，因此只要超过此时间未和此节点再交换封包(可能无资料交换)，则进入此状态。另一种情形是邻居节点自动送过来NA，里面的MAC位址不同 |
   | DELAY      | 自从上次节点可达性状态后过了*ReachableTime*之后都没有再和此节点连系过，向邻居发送NS封包，等待邻居回应，进入此状态，若邻居有回应则进入REACHABLE状态，若在*DELAY_FIRST_PROBE_TIME*期间内无回应(一般而言是5秒)，进入PROBE状态。 |
   | PROBE      | 在DELAY状态向邻居发送NS封包，在*DELAY_FIRST_PROBE_TIME*期间内邻居无回应，进入此状态，此时每*RETRANS_TIMER*秒(预设1秒)发送NS封包直到回应，更改状态为REACHABLE或达到MAX_UNICAST_SOLICIT限制为止(预设3次)，此时状态变为FAILED。 |
   | FAILED     | PROBE状态后无回应或初次向邻居发送NS无回应进入此状态。        |
   | IMCOMPLETE | 向邻居节点发送NS的封包，但未接到邻居回应                     |
   | NONE       | 虚拟状态，初始或删除时预设状态，在初始发送NS前或被从清单要被清掉前的状态(EMPTY)，理论上应该看不到这个状态，因为太短暂 |
   | NOARP      | 系统不会向邻居节点侦测可达性，生命期终止后可被移除           |
   | PERMANENT  | 手动设定，系统不会向邻居节点侦测可达性，只有管理员能删除此清单 |
