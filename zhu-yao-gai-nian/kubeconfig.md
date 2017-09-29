### kubeconfig文件示例：

基于用户名

```
    apiVersion: v1
    clusters:
    - cluster:
        server: http://localhost:8080
      name: local-server
    contexts:
    - context:
        cluster: local-server
        namespace: the-right-prefix
        user: myself
      name: default-context
    current-context: default-context
    kind: Config
    preferences: {}
    users:
    - name: myself
      user:
        password: secret
        username: admin
```

基于证书

```
APIVersion: v1
kind: Config
user:
- name: controllermanager
  user:
   client-certificate: /path/to/file.crt
   client-key: /path/to/file.key
clusters:
- name: local
  clusters:
   certificate-authority: /path/to/ca.crt
contexts:
- context:
   cluster: local
   user: controllermanager
  name: my-context
current-context: my-context

```



