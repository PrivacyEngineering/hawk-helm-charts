
{{- define "actixgo.filter" -}}
{{ template "actixgo.filter.config" . }}
---
{{ template "actixgo.filter.inbound" . }}
{{- end -}}

{{- define "actixgo.filter.config" -}}
{{- $top := index . 0 -}}
{{- $var := index . 1 -}}
# istio api config: https://github.com/istio/api/blob/master/networking/v1alpha3/envoy_filter.gen.json
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  # namespace is important because it is the namespace where the filter will act
  name: actixgo-filter-config
  namespace: {{ $var }}
spec:
  configPatches:
    - applyTo: EXTENSION_CONFIG
      match:
#        context: GATEWAY
        context: SIDECAR_INBOUND
      patch:
        operation: ADD
        value:
          name: actixgo-filter-config
          typed_config:
            "@type": type.googleapis.com/udpa.type.v1.TypedStruct
            type_url: type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm
            value:
              config:
                # envoy api: https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/core/v3/base.proto#envoy-v3-api-msg-config-core-v3-remotedatasource
                vm_config:
                  vm_id: actixgo-filter
                  allow_precompiled: true
                  runtime: envoy.wasm.runtime.v8
                  configuration:
                    "@type": "type.googleapis.com/google.protobuf.StringValue"
                    value: "outbound|80||{{ include "collector.fullname" $top }}.{{ $top.Release.Namespace }}.svc.cluster.local"
                  code:
                    remote:
                      # envoy api for http_uri: https://github.com/envoyproxy/envoy/blob/main/api/envoy/api/v2/core/http_uri.proto
                      http_uri:
                        uri: https://github.com/jmgoyesc/istio-extensions/blob/main/actixgo-filter.wasm?raw=true
#                        uri: http://nginx-serve-filter-service.nginx-serve-filter.svc/actixgo-filter.wasm
                        timeout: 10s
                        cluster: jwks_cluster
                      # command `sha256sum`
#                      sha256: 5c52cd8b899e36f938d71474a9de230d1fde68949d63d88fe905640d319b4c1b
                      sha256: d0b468938af078e0d2c347483ed03d049b93167bcb5e0d7a0416229a26f07139
{{- end -}}
{{- define "actixgo.filter.inbound" -}}
{{- $top := index . 0 -}}
{{- $var := index . 1 -}}
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  # namespace is important because it is the namespace where the filter will act
  name: actixgo-filter
  namespace: {{ $var }}
spec:
  configPatches:
    - applyTo: HTTP_FILTER
      match:
#        context: GATEWAY
        context: SIDECAR_INBOUND
#        context: SIDECAR_OUTBOUND
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
      patch:
        operation: INSERT_BEFORE
        value:
          name: actixgo-filter-config
          config_discovery:
            config_source:
              ads: {}
              initial_fetch_timeout: 0s # wait indefinitely to prevent bad Wasm fetch
            type_urls: [ "type.googleapis.com/envoy.extensions.filters.http.wasm.v3.Wasm"]

{{- end -}}