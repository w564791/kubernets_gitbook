## 在开始之前 {#before-you-begin}

* 了解Istio[身份验证策略](https://istio.io/docs/concepts/security/authn-policy/)和相关的[相互TLS身份验证](https://istio.io/docs/concepts/security/mutual-tls/)概念。
* 安装一个安装了Istio的Kubernetes群集，但不启用全局相互TLS（例如`install/kubernetes/istio-demo.yaml`，按照[安装步骤中](https://istio.io/docs/setup/kubernetes/quick-start/#installation-steps)所述使用，使用[Helm](https://istio.io/docs/setup/kubernetes/helm-install/)时`global.mtls.enabled`设置为false）。
* 为了演示，创建两个命名空间`foo`和`bar`和部署[httpbin](https://github.com/istio/istio/blob/release-0.8/samples/httpbin)和[sleep](https://github.com/istio/istio/tree/master/samples/sleep)与sidecar。另外，运行另一个没有sidecar的sleep应用程序（为了保持它的独立性，在`legacy`命名空间中运行它

```bash
kubectl create ns foo
kubectl apply -f <(istioctl kube-inject -f samples/httpbin/httpbin.yaml) -n foo
kubectl apply -f <(istioctl kube-inject -f samples/sleep/sleep.yaml) -n foo
kubectl create ns bar
kubectl apply -f <(istioctl kube-inject -f samples/httpbin/httpbin.yaml) -n bar
kubectl apply -f <(istioctl kube-inject -f samples/sleep/sleep.yaml) -n bar
kubectl create ns legacy
kubectl apply -f samples/sleep/sleep.yaml -n legacy
```

* 通过使用curl命令检验设定`foo`，`bar`或`legacy`），所有请求都应该返回HTTP代码200。

例如，这里是一个命令检查`sleep.bar`到`httpbin.foo`的可达性：

```
# kubectl exec $(kubectl get pod -l app=sleep -n bar -o jsonpath={.items..metadata.name}) -c sleep -n bar -- curl http://httpbin.foo:8000/ip -s -o /dev/null -w "%{http_code}\n"
200
```

如下命令可以遍历所有请求:

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 200
sleep.legacy to httpbin.bar: 200
```

同时确认系统中没有认证策略

```
# kubectl get policies.authentication.istio.io --all-namespaces
No resources found.
```

## 为命名空间中的所有服务启用相互TLS {#enable-mutual-tls-for-all-services-in-a-namespace}

运行此命令为名称空间`foo`设置命名空间级别策略

```
cat <<EOF | istioctl create -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-1"
  namespace: "foo"
spec:
  peers:
  - mtls:
EOF
```

校验请求\(生效可能需要等几秒?\),可以看出,请求foo命名空间的请求全部失败,同命名空间的也不可访问,没有部署sidecar的应用sleep.legacy不可访问foo命名空间应用

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 503
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 503
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 000
command terminated with exit code 56
sleep.legacy to httpbin.bar: 200
```

添加目标规则以将客户端配置为使用MUTUAL\_TLS：

```
cat <<EOF | istioctl create -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-1"
  namespace: "foo"
spec:
  host: "*.foo.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

校验请求,此时拥有部署有sidecar的应用,能够正常请求foo命名空间的应用,而部署时没有部署sidecar的应用sleep.legacy不可访问foo命名空间的应用

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 000
command terminated with exit code 56
sleep.legacy to httpbin.bar: 200
```

* 假设当前系统中可没有其他DestinationRule规则,\*`*.foo.svc.cluster.local`匹配foo命名空间中的所有服务,

### 清理现场

```
istioctl delete DestinationRule example-1 -n foo
istioctl delete policy example-1 -n foo
```

## 为单一服务启用MUTUAL\_TLS\(`httpbin.bar`\) {#enable-mutual-tls-for-single-service-httpbin-bar}

运行此命令为`httpbin.bar`服务设置一个策略。注意在这个例子中，我们**没有**在元数据中指定名称空间，而是把它放在命令行（`-n bar`）中。

```
$ cat <<EOF | istioctl create -n bar -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-2"
spec:
  targets:
  - name: httpbin
  peers:
  - mtls:
EOF
```

校验请求:此时拥有sidecar的应用均不可请求到httpbin.bar,包括不具有sidecar的应用sleep.legacy也不可请求到httpbin.bar

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 503
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 503
sleep.legacy to httpbin.foo: 200
sleep.legacy to httpbin.bar: 000
command terminated with exit code 56
```

添加MUTUAL\_TLS 目标规则

```
cat <<EOF | istioctl create -n bar -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-2"
spec:
  host: "httpbin.bar.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

校验请求:此时拥有sidecar的应用可请求到httpbin.bar,但不具有sidecar的应用sleep.legacy不可请求到httpbin.bar

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 200
sleep.legacy to httpbin.bar: 000
command terminated with exit code 56
```

如果我们在bar命名空间有其他的服务,那么其他服务是不会受到影响的,这里把tls修改到123端口,8000端口不启用tls认证

```
cat <<EOF | istioctl replace -n bar -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-2"
spec:
  targets:
  - name: httpbin
    ports:
    - number: 1234
  peers:
  - mtls:
EOF
```

校验请求:此时在8000端口上,已经取消了tls认证,但是DestinationRule依旧存在,所有来自有sidecar的应用无法请求成功,但是没有sidecar的应用sleep.legacy能正常请求.

```
root@128:/home/kinglong/istio/tsl# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 503
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 503
sleep.legacy to httpbin.foo: 200
sleep.legacy to httpbin.bar: 200
```

修改DestinationRule到1234端口

```
cat <<EOF | istioctl replace -n bar -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-2"
spec:
  host: httpbin.bar.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
    portLevelSettings:
    - port:
        number: 1234
      tls:
        mode: ISTIO_MUTUAL
EOF
```

校验请求:可以看到请求8000端口都能成功,TLS认证已经修改为1234端口

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 200
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 200
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 200
sleep.legacy to httpbin.bar: 200
```

### 清理现场

```
istioctl delete destinationrule -n bar example-2
istioctl delete policy -n bar example-2
```

## 具有命名空间以及svc级别的策略

假设我们已经在foo命名空间添加了命名空间级别的策略.

```
cat <<EOF | istioctl create -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-1"
  namespace: "foo"
spec:
  peers:
  - mtls:
EOF

```

校验结果: 所有到达httpbin.bar的请求都失败

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}: %{http_code}\n"; done; done
sleep.foo to httpbin.foo: 503
sleep.foo to httpbin.bar: 200
sleep.bar to httpbin.foo: 503
sleep.bar to httpbin.bar: 200
sleep.legacy to httpbin.foo: 000
command terminated with exit code 56
sleep.legacy to httpbin.bar: 200
```

为命名空间配置MUTUAL\_TLS:

```
cat <<EOF | istioctl create -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-1"
  namespace: "foo"
spec:
  host: "*.foo.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

校验请求

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}  code:  %{http_code}\n"; done; done
sleep.foo to httpbin.foo  code:  200
sleep.foo to httpbin.bar  code:  200
sleep.bar to httpbin.foo  code:  200
sleep.bar to httpbin.bar  code:  200
sleep.legacy to httpbin.foo  code:  000
command terminated with exit code 56
sleep.legacy to httpbin.bar  code:  200
```

添加另外一个策略禁用MUTUAL\_TLS,对等部分为空

```
cat <<EOF | istioctl create -n foo -f -
apiVersion: "authentication.istio.io/v1alpha1"
kind: "Policy"
metadata:
  name: "example-3"
spec:
  targets:
  - name: httpbin
EOF

```

校验请求: 此时没有sidecar的sleep.legacy可以正常请求httbin.foo,但是具有sidecar的pod,无法成功请求到httpbin.foo

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}  code:  %{http_code}\n"; done; done
sleep.foo to httpbin.foo  code:  503
sleep.foo to httpbin.bar  code:  200
sleep.bar to httpbin.foo  code:  503
sleep.bar to httpbin.bar  code:  200
sleep.legacy to httpbin.foo  code:  200
sleep.legacy to httpbin.bar  code:  200

```

创建目标规则,禁用服务级别的TLS

```
cat <<EOF | istioctl create -n foo -f -
apiVersion: "networking.istio.io/v1alpha3"
kind: "DestinationRule"
metadata:
  name: "example-3"
spec:
  host: httpbin.foo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
EOF

```

校验请求: 所有pod均成功返回,可以看到svc级别的策略否决了命名空间级别策略

```
# for from in "foo" "bar" "legacy"; do for to in "foo" "bar"; do kubectl exec $(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name}) -c sleep -n ${from} -- curl http://httpbin.${to}:8000/ip -s -o /dev/null -w "sleep.${from} to httpbin.${to}  code:  %{http_code}\n"; done; done
sleep.foo to httpbin.foo  code:  200
sleep.foo to httpbin.bar  code:  200
sleep.bar to httpbin.foo  code:  200
sleep.bar to httpbin.bar  code:  200
sleep.legacy to httpbin.foo  code:  200
sleep.legacy to httpbin.bar  code:  200
```



