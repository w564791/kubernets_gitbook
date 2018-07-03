## 在开始之前

* 部署istio\(本例使用了mtls,若未使用,若未使用,下例第一条使用[samples/bookinfo/routing/route-rule-all-v1.yaml的内容](https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/route-rule-all-v1.yaml)\)
* 部署[bookinfo](https://istio.io/docs/guides/bookinfo/)示例程序
* 将所有流量导向v3,jason用户流量导向v2

```
$   istioctl create -f samples/bookinfo/routing/route-rule-all-v1-mtls.yaml
```

```
  # cat <<EOF| istioctl replace -f -
  apiVersion: networking.istio.io/v1alpha3
  kind: VirtualService
  metadata:
    name: reviews
  spec:
    hosts:
      - reviews
    http:
    - match:
      - headers:
          cookie:
            regex: "^(.*?;)?(user=jason)(;.*)?$"
      route:
      - destination:
          host: reviews
          subset: v2
    - route:
      - destination:
          host: reviews
          subset: v3
EOF
```

## 限制流量

将ratings设置为1qps的限制

1.登录productpage页面,确认当前非jason用户登录时可以看到红星评价,jason用户登录时是黑星评价

2.配置memquota, quota, rule, QuotaSpec, QuotaSpecBinding限制流量,[samples/bookinfo/routing/mixer-rule-ratings-ratelimit.yaml](https://raw.githubusercontent.com/istio/istio/release-0.8/samples/bookinfo/routing/mixer-rule-ratings-ratelimit.yaml)

```
# istioctl create -f samples/bookinfo/routing/mixer-rule-ratings-ratelimit.yaml
```

3.确认memquota已经被创建

```
# kubectl get memquota  -n istio-system handler
NAME      AGE
handler   2m
```

memquota定义了3个不同的方案,如果没有被覆盖,默认每秒请求上限为5000次,还定义了2个覆盖,第一个每5秒上限1个请求如果`destination`是ratings,并且source是reviews 的V3版本,第二个覆盖定义了destination是ratings,每10秒5个请求的上限.覆盖按照从上到下,取第一个匹配的规则.

4.确认quota已经被创建

```
# kubectl -n istio-system get quotas requestcount
NAME           AGE
requestcount   8m
```

quota模板定义了4个`dimensions,`memquota的使用这些`dimensions`来匹配某些属性的请求.`destination`将会被匹配到在 destination.labels\["app"\], destination.service, "unknown"中第一个非空的值,更多信息点击[这里](https://istio.io/docs/reference/config/policy-and-telemetry/expression-language/)

5,确认rule已经被正确创建

```
# kubectl -n istio-system get rules quota
NAME      AGE
quota     13m
```

该rule告诉mixer调用handler.memquota ,并传递使用requestcount.quota构造对象,这有效的将quota模板映射到memquota

6.确认QuotaSpec已经正确创建

```
#  kubectl -n istio-system get QuotaSpec request-count
NAME            AGE
request-count   18m
```

该`QuotaSpec`定义了创建的requestcount  quota限额为1

7,确认`QuotaSpecBinding`被正确创建

```
#  kubectl -n istio-system get QuotaSpecBinding request-count
NAME            AGE
request-count   21m
```

`QuotaSpecBinding`将`QuotaSpec`绑定到我们的想要应用的服务,必须为每个服务定义命名空间,所以QuotaSpecBinding可以不用和我们想要应用的service部署到相同的命名空间

8.刷新productpage页面,v3请求为5秒每个\(多次刷新提示_Ratings service is currently unavailable_\),如果你连续不断的请求,星星每5秒加载一次,如果以jason用户登录,则v2限制为10秒5个请求,对于其他服务,限制为5000QPS速率

