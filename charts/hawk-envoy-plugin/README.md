# hawk-envoy-proxy

[![Apache 2.0 License][license-badge]][license-link]

[license-badge]: https://img.shields.io/github/license/proxy-wasm/proxy-wasm-rust-sdk
[license-link]: https://github.com/PrivacyEngineering/hawk-envoy-plugin/blob/master/LICENSE

Extension for istio envoy to allow trace personal data between rest microservices in kubernetes

![Diagram](./images/diagram.drawio.svg)

## Helm Chart

This helm chart is used to deploy the envoy filter in a target kubernetes-namespace.


### Deployment through Helm


1. Add the helm chart repository (if not already done):
    ```
    helm repo add hawk https://privacyengineering.github.io/hawk-helm-charts/
    ```
2. Install the istio service mesh using `istioctl` with the demo profile:
    ```
    istioctl install --set profile=default -y
    ```
3. Create the namespace where hawk is intended to be applied:
    ```
    kubectl create namespace sock-shop
    ```
4. Create `values.yaml` and modify to your needs (see default values in [`values.yaml`](values.yaml) and the documentation for [Parameters](#parameters)):
    ```
    cat <<EOF > values.yaml
    # example values.yaml
    hawkEnvoyPlugin:
      namespace: sock-shop
      hawkServiceApiUrl: http://hawk-service.hawk.svc.cluster.local/api
      httpbin: true
    EOF
    ```
5. Install hawk envoy plugin and all it's services:
    ```
    helm dependency update
    helm install -f values.yaml sock-shop-hawk-ep hawk/hawk-envoy-plugin --namespace hawk-envoy-plugin --create-namespace
    ```
6. Install the rest of the demo architecture:
    ```
    kubectl apply -f ./02.sock-shop/
    ```

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+
- Istio 1.6+
- [Hawk](https://github.com/PrivacyEngineering/hawk)

## Parameters

### Hawk-envoy-plugin parameters

| Name                                | Description                                                        | Value                                            |
| ----------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------ |
| `hawkEnvoyPlugin.namespace`         | The target namespace to collect tracing data from                  | `"sock-shop"`                                     |
| `hawkEnvoyPlugin.hawkServiceApiUrl` | Hawk Service Api Url in url-schema                                 | `http://hawk-service.hawk.svc.cluster.local/api` |
| `hawkEnvoyPlugin.httpbin`           | Whether a httpbin-namespace should be created for testing purposes | `true`                                           |



## Testing hawk-envoy-plugin

To test the plugin, the helm-chart uses the httpbin-namespace, which is created by the helm chart.

**Note:** The httpbin-namespace is only created if the `hawkEnvoyPlugin.httpbin` parameter is set to `true`.
```console
helm test -n hawk-envoy-plugin sock-shop-hawk-ep --logs
```
