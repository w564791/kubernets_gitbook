### kubeconfig文件示例：

```
from  http://www.jianshu.com/p/41e55f4d0cb8
```

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

```
current-context: federal-context
apiVersion: v1
clusters:
- cluster:
    api-version: v1
    server: http://cow.org:8080
  name: cow-cluster
- cluster:
    certificate-authority: path/to/my/cafile
    server: https://horse.org:4443
  name: horse-cluster
- cluster:
    insecure-skip-tls-verify: true
    server: https://pig.org:443
  name: pig-cluster
contexts:
- context:
    cluster: horse-cluster
    namespace: chisel-ns
    user: green-user
  name: federal-context
- context:
    cluster: pig-cluster
    namespace: saw-ns
    user: black-user
  name: queen-anne-context
kind: Config
preferences:
  colors: true
users:
- name: blue-user
  user:
    token: blue-token
- name: green-user
  user:
    client-certificate: path/to/my/client/cert
    client-key: path/to/my/client/key

```



