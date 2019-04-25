# policy/v1beta1

## PodDisruptionBudget

```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: istio-telemetry
  namespace: istio-system
  labels:
    app: telemetry
    chart: mixer
    heritage: Tiller
    release: istio
    version: 1.1.0
    istio: mixer
    istio-mixer-type: telemetry
spec:

  minAvailable: 1
  selector:
    matchLabels:
      app: telemetry
      release: istio
      istio: mixer
      istio-mixer-type: telemetry
```

