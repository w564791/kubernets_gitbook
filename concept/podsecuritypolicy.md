# Pod Security Policies

Pod安全策略支持对pod创建和更新进行细粒度授权

- [什么是Pod Security Policy?](#什么是Pod Security Policy)
- [启用 Pod Security Policies](#启用 Pod Security Policies)
- [授权Policies](#授权Policies)
- [示例](#示例)
- [Policy 参考](#Policy 参考)



## 什么是Pod Security Policy

Pod安全策略是一种集群级别的资源,用于规范控制pod的一些敏感权限,`PodSecurityPolicy`对象定义了一组条件,这些条件必须与pod一起运行才能被系统接受,他们允许控制管理一下内容:

| 字段名称                                                     | 描述                             |
| ------------------------------------------------------------ | -------------------------------- |
| [`privileged`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#privileged) | 运行特权容器                     |
| [`hostPID`,`hostIPC`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#host-namespaces) | 使用主机`namespace`              |
| [`hostNetwork`,`hostPorts`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#host-namespaces) | 使用主机网络以及端口             |
| [`volumes`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems) | 使用volume资源                   |
| [`allowedHostPaths`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems) | 使用主机文件系统                 |
| [`allowedFlexVolumes`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#flexvolume-drivers) | `Flexvolume`驱动程序白名单       |
| [`fsGroup`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems) | 分配拥有pod卷的`FSGroup`         |
| [`readOnlyRootFilesystem`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems) | 要求使用只读根文件系统           |
| [`runAsUser`, `runAsGroup`, `supplementalGroups`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#users-and-groups) | 容器的用户和组ID                 |
| [`allowPrivilegeEscalation`, `defaultAllowPrivilegeEscalation`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#privilege-escalation) | 限制升级为root权限               |
| [`defaultAddCapabilities`, `requiredDropCapabilities`, `allowedCapabilities`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#capabilities) | Linux capabilities               |
| [`seLinux`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#selinux) | 容器的`SELinux`                  |
| [`allowedProcMountTypes`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#allowedprocmounttypes) | 容器允许的Proc Mount类型         |
| [`AppArmor`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#apparmor) | 容器使用的`AppArmor`配置文件     |
| [`seccomp`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#seccomp) | 容器使用的`seccomp`配置文件      |
| [`sysctl`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#sysctl) | 容器使用的`sysctl`note[p配置文件 |



## 启用 Pod Security Policies

Pod security policy控制是作为可选(但是推荐)的`admission controller`,通过启用`admission controller`来强制执行`PodSecurityPolices`,但是这样做如果不授权任何`policy`,将阻止在集群中创建任何pod

## 授权Policies

当`PodSecurityPolicy `资源被创建,不会有任何作用,为了使用`PodSecurityPolicy `资源,请求的`user`以及`service account`需要授权使用该policy,通过`use`动词使用该policy.

大部分`kubernetes`集群的pod不会被`user`直接创建,他们通常作为`Deployment`,`ReplicaSet`的一部分间接创建,授予控制器对策略的访问权限将授予该控制器创建的*所有*pod的访问权限，因此，授权策略的首选方法是授予对pod的`serviceaccount`的访问权限（参见[示例](#示例))。

### 通过RBAC

RBAC是标准的`kubernetes`授权模式,并且可以很容易地用于授权使用策略。

首先，`Role`或`ClusterRole`需要授予访问权以use所需的策略。授予访问权限的规则如下所示：

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: <role name>
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - <list of policies to authorize>
```

或使用如下命令

```bash
# kubectl  create clusterrole restricted-psp --verb=use --resource-name=restricted --resource=podsecuritypolicies

```



然后`(Cluster)Role`绑定到授权user(s)：

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: <binding name>
roleRef:
  kind: ClusterRole
  name: <role name>
  apiGroup: rbac.authorization.k8s.io
subjects:
# 认证具体的service accounts:
- kind: ServiceAccount
  name: <authorized service account name>
  namespace: <authorized pod namespace>
# 认证具体用户users (不推荐):
- kind: User
  apiGroup: rbac.authorization.k8s.io
  name: <authorized user name>
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: <authorized group name>
```

如果使用`RoleBinding`(不是`ClusterRoleBinding`)，它将仅授予在与绑定相同的命名空间中运行的pod的使用。这可以与系统组配对，以授予对命名空间中运行的所有pod的访问权限：

```yaml
# 允许命名空间内所有service accounts:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts
#允许所有的已授权用户,与上面等效
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:authenticated
```

### 故障排除

* `Controller Manager`必须通过安全端口与API通信,并且不得有超级用户权限,否则请求将绕过身份验证和授权模块,所有的`PodSecurityPolicy `策略将被接受,user可以创建特权容器,有关配置Controller Manager授权的更多详细信息，请参阅 [Controller Roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#controller-roles)

## Policy Order

除了限制pod创建和更新，pod安全策略还可用于为其控制的许多字段提供默认值。当有多个策略可用时，pod安全策略控制器根据以下条件选择策略：

1. 如果任何策略成功验证了pod而不更改它，则使用它们
2. 如果是pod创建请求，则使用按字母顺序排列的第一个有效策略
3. 如果是pod更新请求，则返回错误，因为在更新操作期间不允许pod突变

## 示例

*此示例假定您具有已启用`PodSecurityPolicy`的 `admission controller`的集群，并且您具有集群管理员权限*

### 建立

此处创建namespace以及service account,并且认证service account为非admin权限

```bash
kubectl create namespace psp-example
kubectl create serviceaccount -n psp-example fake-user
kubectl create rolebinding -n psp-example fake-editor --clusterrole=edit --serviceaccount=psp-example:fake-user
```

要明确我们正在扮演的用户并节约一些输入，请创建2个别名：

```bash
alias kubectl-admin='kubectl -n psp-example'
alias kubectl-user='kubectl --as=system:serviceaccount:psp-example:fake-user -n psp-example'
```

### 创建policy以及pod

```bash
kubectl create -f- <<EOF
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: example
spec:
  privileged: false  # Don't allow privileged pods!
  # The rest fills in some required fields.
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - '*'
EOF

```

使用unprivileged 用户创建pod

```bash
kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: unable to validate against any pod security policy: []
```

**发生了什么**: 虽然已创建`PodSecurityPolicy`，但pod的`service account`和`fake-user`都无权使用新策略

```bash
kubectl-user auth can-i use podsecuritypolicy/example
no
```

创建`rolebinding`以向fake-user授予`use`示例策略：

**注意**：这不是推荐的方式！有关首选方法，请参阅下一节。

```bash
kubectl-admin create role psp:unprivileged \
    --verb=use \
    --resource=podsecuritypolicy \
    --resource-name=example
role "psp:unprivileged" created

kubectl-admin create rolebinding fake-user:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:fake-user
rolebinding "fake-user:psp:unprivileged" created

kubectl-user auth can-i use podsecuritypolicy/example
yes
```

现在重新创建pod

```bash
kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
pod "pause" created
```

它按预期工作！但是仍然应该拒绝任何创建特权pod的尝试：

```bash
kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      privileged
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
      securityContext:
        privileged: true
EOF
Error from server (Forbidden): error when creating "STDIN": pods "privileged" is forbidden: unable to validate against any pod security policy: [spec.containers[0].securityContext.privileged: Invalid value: true: Privileged containers are not allowed]
```

在继续之前删除pod:

```bash
kubectl-user delete pod pause
```

### 运行另一个pod

```bash
kubectl-user run pause --image=k8s.gcr.io/pause
deployment "pause" created

kubectl-user get pods
No resources found.

kubectl-user get events | head -n 2
LASTSEEN   FIRSTSEEN   COUNT     NAME              KIND         SUBOBJECT                TYPE      REASON                  SOURCE                                  MESSAGE
1m         2m          15        pause-7774d79b5   ReplicaSet                            Warning   FailedCreate            replicaset-controller                   Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request
```

**发生了什么**: 我们已经为我们的fake-user绑定了`psp:unfrivileged`的role,为什么我们得到错误:`Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request`?问题的关键在于`replicaset-controller`,Fake-user成功创建了`Deployment`（成功创建了一个`replicaset`）,但是当``replicaset`创建pod时，它无权使用示例`podsecuritypolicy`。

要解决此问题，请将名为`psp:unprivileged`的role绑定到pod的`service account`。在这种情况下（因为我们没有指定），`service account`名为`default`：

```bash]
kubectl-admin create rolebinding default:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:default
rolebinding "default:psp:unprivileged" created
```

现在，如果你给它一分钟重试，`replicaset-controller`最终应该成功创建pod：

```
kubectl-user get pods --watch
NAME                    READY     STATUS    RESTARTS   AGE
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       ContainerCreating   0         1s
pause-7774d79b5-qrgcb   1/1       Running   0         2s
```

### 清理

删除namespace以清除大多数示例资源：

```
kubectl-admin delete ns psp-example
namespace "psp-example" deleted
```

请注意，``PodSecurityPolicy`属于集群资源，必须单独清除

```bash
kubectl-admin delete psp example
podsecuritypolicy "example" deleted
```

### 示例Policies

## 

这是您可以创建的限制最少的策略，相当于不使用pod安全策略许可控制器：

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```



这是一个限制性策略的示例，要求用户以非特权用户身份运行，阻止可能的升级到root，并需要使用多种安全机制。

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'docker/default'
    apparmor.security.beta.kubernetes.io/allowedProfileNames: 'runtime/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'docker/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName:  'runtime/default'
spec:
  privileged: false
  # Required to prevent escalations to root.
  allowPrivilegeEscalation: false
  # This is redundant with non-root + disallow privilege escalation,
  # but we can provide it for defense in depth.
  requiredDropCapabilities:
    - ALL
  # Allow core volume types.
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    # Assume that persistentVolumes set up by the cluster admin are safe to use.
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    # Require the container to run without root privileges.
    rule: 'MustRunAsNonRoot'
  seLinux:
    # This policy assumes the nodes are using AppArmor rather than SELinux.
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false
```

## Policy 参考

### Privileged

**Privileged** - determines if any container in a pod can enable privileged mode. By default a container is not allowed to access any devices on the host, but a “privileged” container is given access to all devices on the host. This allows the container nearly all the same access as processes running on the host. This is useful for containers that want to use linux capabilities like manipulating the network stack and accessing devices.

### Host namespaces

**HostPID** - Controls whether the pod containers can share the host process ID namespace. Note that when paired with ptrace this can be used to escalate privileges outside of the container (ptrace is forbidden by default).

**HostIPC** - Controls whether the pod containers can share the host IPC namespace.

**HostNetwork** - Controls whether the pod may use the node network namespace. Doing so gives the pod access to the loopback device, services listening on localhost, and could be used to snoop on network activity of other pods on the same node.

**HostPorts** - Provides a whitelist of ranges of allowable ports in the host network namespace. Defined as a list of `HostPortRange`, with `min`(inclusive) and `max`(inclusive). Defaults to no allowed host ports.

**AllowedHostPaths** - See [Volumes and file systems](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems).

### Volumes and file systems

**Volumes** - Provides a whitelist of allowed volume types. The allowable values correspond to the volume sources that are defined when creating a volume. For the complete list of volume types, see [Types of Volumes](https://kubernetes.io/docs/concepts/storage/volumes/#types-of-volumes). Additionally, `*` may be used to allow all volume types.

The **recommended minimum set** of allowed volumes for new PSPs are:

- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- secret
- projected

**FSGroup** - Controls the supplemental group applied to some volumes.

- *MustRunAs* - Requires at least one `range` to be specified. Uses the minimum value of the first range as the default. Validates against all ranges.
- *MayRunAs* - Requires at least one `range` to be specified. Allows `FSGroups` to be left unset without providing a default. Validates against all ranges if `FSGroups` is set.
- *RunAsAny* - No default provided. Allows any `fsGroup` ID to be specified.

**AllowedHostPaths** - This specifies a whitelist of host paths that are allowed to be used by hostPath volumes. An empty list means there is no restriction on host paths used. This is defined as a list of objects with a single `pathPrefix` field, which allows hostPath volumes to mount a path that begins with an allowed prefix, and a `readOnly` field indicating it must be mounted read-only. For example:

```yaml
allowedHostPaths:
  # This allows "/foo", "/foo/", "/foo/bar" etc., but
  # disallows "/fool", "/etc/foo" etc.
  # "/foo/../" is never valid.
  - pathPrefix: "/foo"
    readOnly: true # only allow read-only mounts
```

> Warning:
>
> There are many ways a container with unrestricted access to the host filesystem can escalate privileges, including reading data from other containers, and abusing the credentials of system services, such as Kubelet.
>
> Writeable hostPath directory volumes allow containers to write to the filesystem in ways that let them traverse the host filesystem outside the `pathPrefix`. `readOnly: true`, available in Kubernetes 1.11+, must be used on **all** `allowedHostPaths` to effectively limit access to the specified `pathPrefix`.

**ReadOnlyRootFilesystem** - Requires that containers must run with a read-only root filesystem (i.e. no writable layer).

### Flexvolume drivers

This specifies a whitelist of Flexvolume drivers that are allowed to be used by flexvolume. An empty list or nil means there is no restriction on the drivers. Please make sure [`volumes`](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#volumes-and-file-systems)field contains the `flexVolume` volume type; no Flexvolume driver is allowed otherwise.

For example:

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: allow-flex-volumes
spec:
  # ... other spec fields
  volumes:
    - flexVolume
  allowedFlexVolumes:
    - driver: example/lvm
    - driver: example/cifs
```

### Users and groups

**RunAsUser** - Controls which user ID the containers are run with.

- *MustRunAs* - Requires at least one `range` to be specified. Uses the minimum value of the first range as the default. Validates against all ranges.
- *MustRunAsNonRoot* - Requires that the pod be submitted with a non-zero `runAsUser` or have the `USER` directive defined (using a numeric UID) in the image. No default provided. Setting `allowPrivilegeEscalation=false` is strongly recommended with this strategy.
- *RunAsAny* - No default provided. Allows any `runAsUser` to be specified.

**RunAsGroup** - Controls which primary group ID the containers are run with.

- *MustRunAs* - Requires at least one `range` to be specified. Uses the minimum value of the first range as the default. Validates against all ranges.
- *MustRunAsNonRoot* - Requires that the pod be submitted with a non-zero `runAsUser` or have the `USER` directive defined (using a numeric GID) in the image. No default provided. Setting `allowPrivilegeEscalation=false` is strongly recommended with this strategy.
- *RunAsAny* - No default provided. Allows any `runAsGroup` to be specified.

**SupplementalGroups** - Controls which group IDs containers add.

- *MustRunAs* - Requires at least one `range` to be specified. Uses the minimum value of the first range as the default. Validates against all ranges.
- *MayRunAs* - Requires at least one `range` to be specified. Allows `supplementalGroups` to be left unset without providing a default. Validates against all ranges if `supplementalGroups` is set.
- *RunAsAny* - No default provided. Allows any `supplementalGroups` to be specified.

### Privilege Escalation

These options control the `allowPrivilegeEscalation` container option. This bool directly controls whether the [`no_new_privs`](https://www.kernel.org/doc/Documentation/prctl/no_new_privs.txt) flag gets set on the container process. This flag will prevent `setuid` binaries from changing the effective user ID, and prevent files from enabling extra capabilities (e.g. it will prevent the use of the `ping` tool). This behavior is required to effectively enforce `MustRunAsNonRoot`.

**AllowPrivilegeEscalation** - Gates whether or not a user is allowed to set the security context of a container to `allowPrivilegeEscalation=true`. This defaults to allowed so as to not break setuid binaries. Setting it to `false` ensures that no child process of a container can gain more privileges than its parent.

**DefaultAllowPrivilegeEscalation** - Sets the default for the `allowPrivilegeEscalation` option. The default behavior without this is to allow privilege escalation so as to not break setuid binaries. If that behavior is not desired, this field can be used to default to disallow, while still permitting pods to request `allowPrivilegeEscalation` explicitly.

### Capabilities

Linux capabilities provide a finer grained breakdown of the privileges traditionally associated with the superuser. Some of these capabilities can be used to escalate privileges or for container breakout, and may be restricted by the PodSecurityPolicy. For more details on Linux capabilities, see [capabilities(7)](http://man7.org/linux/man-pages/man7/capabilities.7.html).

The following fields take a list of capabilities, specified as the capability name in ALL_CAPS without the `CAP_` prefix.

**AllowedCapabilities** - Provides a whitelist of capabilities that may be added to a container. The default set of capabilities are implicitly allowed. The empty set means that no additional capabilities may be added beyond the default set. `*` can be used to allow all capabilities.

**RequiredDropCapabilities** - The capabilities which must be dropped from containers. These capabilities are removed from the default set, and must not be added. Capabilities listed in `RequiredDropCapabilities` must not be included in `AllowedCapabilities` or `DefaultAddCapabilities`.

**DefaultAddCapabilities** - The capabilities which are added to containers by default, in addition to the runtime defaults. See the [Docker documentation](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) for the default list of capabilities when using the Docker runtime.

### SELinux

- *MustRunAs* - Requires `seLinuxOptions` to be configured. Uses `seLinuxOptions` as the default. Validates against `seLinuxOptions`.
- *RunAsAny* - No default provided. Allows any `seLinuxOptions` to be specified.

### AllowedProcMountTypes

`allowedProcMountTypes` is a whitelist of allowed ProcMountTypes. Empty or nil indicates that only the `DefaultProcMountType` may be used.

`DefaultProcMount` uses the container runtime defaults for readonly and masked paths for /proc. Most container runtimes mask certain paths in /proc to avoid accidental security exposure of special devices or information. This is denoted as the string `Default`.

The only other ProcMountType is `UnmaskedProcMount`, which bypasses the default masking behavior of the container runtime and ensures the newly created /proc the container stays intact with no modifications. This is denoted as the string `Unmasked`.

### AppArmor

Controlled via annotations on the PodSecurityPolicy. Refer to the [AppArmor documentation](https://kubernetes.io/docs/tutorials/clusters/apparmor/#podsecuritypolicy-annotations).

### Seccomp

The use of seccomp profiles in pods can be controlled via annotations on the PodSecurityPolicy. Seccomp is an alpha feature in Kubernetes.

**seccomp.security.alpha.kubernetes.io/defaultProfileName** - Annotation that specifies the default seccomp profile to apply to containers. Possible values are:

- `unconfined` - Seccomp is not applied to the container processes (this is the default in Kubernetes), if no alternative is provided.
- `docker/default` - The Docker default seccomp profile is used.
- `localhost/<path>` - Specify a profile as a file on the node located at `<seccomp_root>/<path>`, where `<seccomp_root>` is defined via the `--seccomp-profile-root` flag on the Kubelet.

**seccomp.security.alpha.kubernetes.io/allowedProfileNames** - Annotation that specifies which values are allowed for the pod seccomp annotations. Specified as a comma-delimited list of allowed values. Possible values are those listed above, plus `*` to allow all profiles. Absence of this annotation means that the default cannot be changed.

### Sysctl

Controlled via annotations on the PodSecurityPolicy. Refer to the [Sysctl documentation](https://kubernetes.io/docs/concepts/cluster-administration/sysctl-cluster/#podsecuritypolicy)