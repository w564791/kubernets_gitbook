# 在kubernetes集群中部署calico

## Requirements {#requirements}

* kubelet必须配置为CNI \(e.g --network-plugin=cni\).
* kube-proxy 必须运行为iptables模式. 该模式从 Kubernetes v1.2.0.开始为默认模式
* kube-proxy 不能设置 --masquerade-all 参数, 与calico的策略冲突.
* Kubernetes NetworkPolicy API 需要Kubernetes  v1.3.0以上.
* 当RBAC  启用时, 需要配置正确的role以及serviceaccount.

## [Calico Hosted Install](https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted) {#calico-hosted-install}

kubernetes集群版本&gt;=v1.4时，使用此方法，Calico将运行为DaemonSet。本处使用（Calico Kubernetes Hosted Install）方法部署

### RBAC授权

```
kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/rbac.yaml
```

## Install Calico {#install-calico}

```
wget https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/calico.yaml
```

编辑yaml文件，需要修改的内容如下：

    # Calico Version v3.0.4
    # https://docs.projectcalico.org/v3.0/releases#v3.0.4
    # This manifest includes the following component versions:
    #   calico/node:v3.0.4
    #   calico/cni:v2.0.3
    #   calico/kube-controllers:v2.0.2

    # This ConfigMap is used to configure a self-hosted Calico installation.
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: calico-config
      namespace: kube-system
    data:
      # Configure this with the location of your etcd cluster.
      etcd_endpoints: "https://10.0.0.156:2379" #etcd通信地址，注意通信协议

      # Configure the Calico backend to use.
      calico_backend: "bird"

      # The CNI network configuration to install on each node.
      cni_network_config: |-
        {
          "name": "k8s-pod-network",
          "cniVersion": "0.3.0",
          "plugins": [
            {
                "type": "calico",
                "etcd_endpoints": "__ETCD_ENDPOINTS__",
                "etcd_key_file": "__ETCD_KEY_FILE__",
                "etcd_cert_file": "__ETCD_CERT_FILE__",
                "etcd_ca_cert_file": "__ETCD_CA_CERT_FILE__",
                "log_level": "info",
                "mtu": 1500,
                "ipam": {
                    "type": "calico-ipam"
                },
                "policy": {
                    "type": "k8s",
                    "k8s_api_root": "https://__KUBERNETES_SERVICE_HOST__:__KUBERNETES_SERVICE_PORT__",
                    "k8s_auth_token": "__SERVICEACCOUNT_TOKEN__"
                },
                "kubernetes": {
                    "kubeconfig": "__KUBECONFIG_FILEPATH__"
                }
            },
            {
              "type": "portmap",
              "snat": true,
              "capabilities": {"portMappings": true}
            }
          ]
        }

      # If you're using TLS enabled etcd uncomment the following.
      # You must also populate the Secret below with these files.
      etcd_ca: "/calico-secrets/etcd-ca"   # "/calico-secrets/etcd-ca" 证书绝对路径
      etcd_cert: "/calico-secrets/etcd-cert" # "/calico-secrets/etcd-cert"
      etcd_key: "/calico-secrets/etcd-key"  # "/calico-secrets/etcd-key"

    ---

    # The following contains k8s Secrets for use with a TLS enabled etcd cluster.
    # For information on populating Secrets, see http://kubernetes.io/docs/user-guide/secrets/
    apiVersion: v1
    kind: Secret
    type: Opaque
    metadata:
      name: calico-etcd-secrets
      namespace: kube-system
    data:
      # Populate the following files with etcd TLS configuration if desired, but leave blank if
      # not using TLS for etcd.
      # This self-hosted install expects three files with the following names.  The values
      # should be base64 encoded strings of the entire contents of each file.
      etcd-key: "" #证书内容base64编码 cat certificate|base64
      etcd-cert: ""#证书内容base64编码

      etcd-ca: ""#证书内容base64编码

    ---

    # This manifest installs the calico/node container, as well
    # as the Calico CNI plugins and network config on
    # each master and worker node in a Kubernetes cluster.
    kind: DaemonSet
    apiVersion: extensions/v1beta1
    metadata:
      name: calico-node
      namespace: kube-system
      labels:
        k8s-app: calico-node
    spec:
      selector:
        matchLabels:
          k8s-app: calico-node
      updateStrategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
      template:
        metadata:
          labels:
            k8s-app: calico-node
          annotations:
            scheduler.alpha.kubernetes.io/critical-pod: ''
        spec:
          hostNetwork: true
          tolerations:
            # Make sure calico/node gets scheduled on all nodes.
            - effect: NoSchedule
              operator: Exists
            # Mark the pod as a critical add-on for rescheduling.
            - key: CriticalAddonsOnly
              operator: Exists
            - effect: NoExecute
              operator: Exists
          serviceAccountName: calico-node
          # Minimize downtime during a rolling upgrade or deletion; tell Kubernetes to do a "force
          # deletion": https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods.
          terminationGracePeriodSeconds: 0
          containers:
            # Runs calico/node container on each Kubernetes node.  This
            # container programs network policy and routes on each
            # host.
            - name: calico-node
              image: quay.io/calico/node:v3.0.4
              env:
                # The location of the Calico etcd cluster.
                - name: ETCD_ENDPOINTS
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_endpoints
                # Choose the backend to use.
                - name: CALICO_NETWORKING_BACKEND
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: calico_backend
                # Cluster type to identify the deployment type
                - name: CLUSTER_TYPE
                  value: "k8s,bgp"
                # Disable file logging so `kubectl logs` works.
                - name: CALICO_DISABLE_FILE_LOGGING
                  value: "true"
                # Set noderef for node controller.
                - name: CALICO_K8S_NODE_REF
                  valueFrom:
                    fieldRef:
                      fieldPath: spec.nodeName
                # Set Felix endpoint to host default action to ACCEPT.
                - name: FELIX_DEFAULTENDPOINTTOHOSTACTION
                  value: "ACCEPT"
                # The default IPv4 pool to create on startup if none exists. Pod IPs will be
                # chosen from this range. Changing this value after installation will have
                # no effect. This should fall within `--cluster-cidr`.
                - name: CALICO_IPV4POOL_CIDR
                  value: "192.168.0.0/16" #此处需要修改为controller里配置的IP池
                - name: CALICO_IPV4POOL_IPIP
                  value: "Always"
                # Disable IPv6 on Kubernetes.
                - name: FELIX_IPV6SUPPORT
                  value: "false"
                # Set Felix logging to "info"
                - name: FELIX_LOGSEVERITYSCREEN
                  value: "info"
                # Set MTU for tunnel device used if ipip is enabled
                - name: FELIX_IPINIPMTU
                  value: "1440"
                # Location of the CA certificate for etcd.
                - name: ETCD_CA_CERT_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_ca
                # Location of the client key for etcd.
                - name: ETCD_KEY_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_key
                # Location of the client certificate for etcd.
                - name: ETCD_CERT_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_cert
                # Auto-detect the BGP IP address.
                - name: IP
                  value: "autodetect"
                - name: FELIX_HEALTHENABLED
                  value: "true"
              securityContext:
                privileged: true
              resources:
                requests:
                  cpu: 250m
              livenessProbe:
                httpGet:
                  path: /liveness
                  port: 9099
                periodSeconds: 10
                initialDelaySeconds: 10
                failureThreshold: 6
              readinessProbe:
                httpGet:
                  path: /readiness
                  port: 9099
                periodSeconds: 10
              volumeMounts:
                - mountPath: /lib/modules
                  name: lib-modules
                  readOnly: true
                - mountPath: /var/run/calico
                  name: var-run-calico
                  readOnly: false
                - mountPath: /calico-secrets
                  name: etcd-certs
            # This container installs the Calico CNI binaries
            # and CNI network config file on each node.
            - name: install-cni
              image: quay.io/calico/cni:v2.0.3
              command: ["/install-cni.sh"]
              env:
                # Name of the CNI config file to create.
                - name: CNI_CONF_NAME
                  value: "10-calico.conflist"
                # The location of the Calico etcd cluster.
                - name: ETCD_ENDPOINTS
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_endpoints
                # The CNI network config to install on each node.
                - name: CNI_NETWORK_CONFIG
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: cni_network_config
              volumeMounts:
                - mountPath: /host/opt/cni/bin
                  name: cni-bin-dir
                - mountPath: /host/etc/cni/net.d
                  name: cni-net-dir
                - mountPath: /calico-secrets
                  name: etcd-certs
          volumes:
            # Used by calico/node.
            - name: lib-modules
              hostPath:
                path: /lib/modules
            - name: var-run-calico
              hostPath:
                path: /var/run/calico
            # Used to install CNI.
            - name: cni-bin-dir
              hostPath:
                path: /opt/cni/bin
            - name: cni-net-dir
              hostPath:
                path: /etc/cni/net.d
            # Mount in the etcd TLS secrets.
            - name: etcd-certs
              secret:
                secretName: calico-etcd-secrets

    ---

    # This manifest deploys the Calico Kubernetes controllers.
    # See https://github.com/projectcalico/kube-controllers
    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      name: calico-kube-controllers
      namespace: kube-system
      labels:
        k8s-app: calico-kube-controllers
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
        scheduler.alpha.kubernetes.io/tolerations: |
          [{"key": "dedicated", "value": "master", "effect": "NoSchedule" },
           {"key":"CriticalAddonsOnly", "operator":"Exists"}]
    spec:
      # The controllers can only have a single active instance.
      replicas: 1
      strategy:
        type: Recreate
      template:
        metadata:
          name: calico-kube-controllers
          namespace: kube-system
          labels:
            k8s-app: calico-kube-controllers
        spec:
          # The controllers must run in the host network namespace so that
          # it isn't governed by policy that would prevent it from working.
          hostNetwork: true
          serviceAccountName: calico-kube-controllers
          containers:
            - name: calico-kube-controllers
              image: quay.io/calico/kube-controllers:v2.0.2
              env:
                # The location of the Calico etcd cluster.
                - name: ETCD_ENDPOINTS
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_endpoints
                # Location of the CA certificate for etcd.
                - name: ETCD_CA_CERT_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_ca
                # Location of the client key for etcd.
                - name: ETCD_KEY_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_key
                # Location of the client certificate for etcd.
                - name: ETCD_CERT_FILE
                  valueFrom:
                    configMapKeyRef:
                      name: calico-config
                      key: etcd_cert
                # Choose which controllers to run.
                - name: ENABLED_CONTROLLERS
                  value: policy,profile,workloadendpoint,node
              volumeMounts:
                # Mount in the etcd TLS secrets.
                - mountPath: /calico-secrets
                  name: etcd-certs
          volumes:
            # Mount in the etcd TLS secrets.
            - name: etcd-certs
              secret:
                secretName: calico-etcd-secrets

    ---

    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: calico-kube-controllers
      namespace: kube-system

    ---

    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: calico-node
      namespace: kube-system


## [Custom Installation](https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/integration) {#custom-installation}

除了使用kubernetes的DaemonSet方法运行，也可以使用ansible，chef，bash等办法。

（此处不介绍该方法）

