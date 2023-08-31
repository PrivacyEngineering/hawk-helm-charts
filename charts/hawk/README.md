# Hawk

![workflow](https://github.com/PrivacyEngineering/hawk/actions/workflows/main.yml/badge.svg)

The Hawk Framework provides a way of tracking the dataflow between applications and allows for GDPR
related tags to be added to the data references. It also features an analytical dashboard about the
GDPR related information and integration for using the ratio of GDPR-tagged data in e.g. Flagger
Canary releases.

## Concept

The concept is to archive this goal is to intercept the traffic between the individual applications
/ services. This idea is called Hawk Core. It can be either done by (A) Framework Integration inside
the application or outside the application using (B) Service Mesh Integration, if available. While
the Framework integration allows to interact with the Hawk API directly inside the Service and gives
the possibility to intercept encrypted and also external traffic, the application itself must be
modified. The Service Mesh solution can be installed without modifying any application. Both
solutions can be active in parallel. Currently the only integrations
are [EnvoyProxy / Istio Service Mesh Integration]() and [Java Framework Integration]() for HTTP and
JSON bodies only.

When a Packet is intercepted it will be parsed, according to the protocol used. The parsing searches
for possible custom data / personal data or more concretely for atomic data values of type string or
number. So the User Email might be one example of this (and not the whole User object). The idea is
to build a selector for each individual atomic data field and saving it. This selector includes the
destination host and some kind of endpoint abstraction. In case of HTTP the method and the path. And
also the a phase which might be request or response, the namespace of the data which is header or
body in case of HTTP, the format which describes if this data was found in a key-value based format
or in some more complex format like JSON and finally the path which is protocol and format dependend
to describe where this data lies inside the packet. When implemented correctly, these values should
provide a protocol independent and context aware selector. Using the selector, it is also possible
to find / track data in other packets with same endpoint. To reduce size many on these selectors
might be aggregated to reduce the size. One example right here might be a list of users. We dont
need to have a selector for each individual User Email, instead we only need to provide a reference
to the array and which path for each entry inside the array. E.g. `$.users.[0].email`
, `$.users.[1].email` ... -> `$.users.[*].email`. This aggregated selector is called `UsageField`.
For each such packet parsed we might get a list of `UsageField`s. This list is tagged with some
metadata and represents one `Usage` object.

GDPR relevant data is added using `Field`s and `Mapping`s. A field again represents one atomic data
unit like a User Email. We can also add a description, some legal bases, whether it is personal data
/ special categories personal data and many more describing information. The next component is
the `Mapping`, which can be created at max once per endpoint. This mapping then specifies a list
of `MappingField`s, where each individual `MappingField` represents a mapping between a `Field` and
a `UsageField`. When every endpoint is mapped accordingly, it is possible for example to see from
where and when a User Email is sent to which other application / service and with which other data.

The [Hawk Service](https://github.com/PrivacyEngineering/hawk-service) is the central component for
all of these entities, as all integrations submit their `Usage`s to here. Also `Mapping`s
and `Field`s can be created here via REST API. The Hawk Service is stateless and allows for
Horizontal scaling. The Database PostgreSQL can be used, but also e.g. YugabyteDB or CockroachDB are
possible, which makes the whole Hawk Framework scalable. But the Hawk Service also serves as a base
for Hawk Release, which accesses the metrics from here. These metric include e.g. how many `Usage`s
where collected and how many of those endpoints have a `Mapping`. To visualize the Data collected,
we can use [Hawk Core Monitor](https://github.com/PrivacyEngineering/hawk-core-monitor). It contains
a UI for creating fields and mappings really quickly and listing them in a nice way. And also a
Grafana Dashboard which is used to visualize the data collected and giving a summary of it. Both of
these components use Hawk Service as a Backend.

The last component is Hawk Build, which is a GitHub Action that allows to be notified when the API
of a service is changed. These changes can be then update in the Hawk Core Monitoring interface. The
Hawk Release can constantly validate the coverage of mapped endpoints to prevent deploying unmapped
endpoints.

## Problems solved

The Hawk Framework helps the company to be compliant with the GDPR, to avoid fines. The data
protection officer can use this software to keep updated about privacy related information and
change the privacy policy accordingly.

## Deployment Guide

1. Install the istio service mesh using `istioctl` with the demo profile:
    ```
    istioctl install --set profile=default -y
    ```
2. Create an ingress gateway for the hawk services:
    ```
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm install nginx-ingress ingress-nginx/ingress-nginx
    ```
3. Create the namespace where hawk is intended to be applied:
    ```
    kubectl create namespace sock-shop
    ```
4. Install hawk core and all it's services:
    ```
    helm dependency update
    helm install -f values.yaml hawk . --namespace hawk --create-namespace
    ```
5. Install the rest of the demo architecture:
    ```
    kubectl apply -f ./02.sock-shop/
    ```

### Hawk Core

This repository feature a Helm Chart which can be used to install this software in a Kubernetes
environment using Helm. It's also possible to install the application in a Non-Kubernetes
environment or configuring them more individual using the Docker Images of them. The Istio / Envoy
integration is only available in specific Kubernetes environments.
The [Java integration](https://github.com/PrivacyEngineering/hawk-integration-java) is available in
every environment. It needs a connection to the Hawk Service. When possible, the Envoy Integration
is preferred as it's less effort to install. You must choose at least one integration.

#### Helm

The Helm Chart (WIP), installs the Hawk-Service, a default PostgreSQL database, Hawk Core Monitor (
nginx + monitor + grafana) and the Istio / Envoy integration if selected.

```shell
helm repo add hawk https://github.com/PrivacyEngineering/hawk/releases/download/1.0.1
helm install PrviacyEngineering/hawk
```

Replace VERSION with the [newest version](https://github.com/TUB-CNPE-TB/hawk/releases) of the chart.
Alternatively, you can also download the hawk-VERSION.tgz of the release you wish and execute:
```shell
helm install ./hawk-VERSION.tgz
```

See the [values.yaml](values.yaml) for configuration options.

You can now see the generated Notes of Helm Chart, to know how to access the [Hawk Core Monitor UI].

#### Docker

The following Docker Images are available, when not choosing Helm:

| Name                                                                         | Image                    | Description                                                                                                                    |
|------------------------------------------------------------------------------|--------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| [Hawk Service](https://github.com/PrivacyEngineering/hawk-service)           | p4skal/hawk-service      | Required: Backend for Hawk Core & Hawk Release                                                                                 |
| [Hawk Core Monitor](https://github.com/PrivacyEngineering/hawk-core-monitor) | p4skal/hawk-core-monitor | Optional: UI for managing Mappings, Fields (can be imported via. JSON directly in the Hawk-Service) and visualizing Data flow. |

The Hawk Service is pretty simple, it uses a PostgreSQL Database, just pass the required Environment
variables described in [Hawk Service](https://github.com/PrivacyEngineering/hawk-service).

For Hawk Core Monitor things get a little bit more complicated as it consists of two components.
First the [Configuration UI](https://github.com/PrivacyEngineering/hawk-core-monitor). This
component needs to have access to the Hawk Service. By default it expects the Hawk Service API to be
available reverse-proxied on the path. To change that you can provide an Environment variable. The
second component is a Grafana instance with specific Plugins, Datasource and Dashboards.
See [Grafana Deployment](templates/grafana-deployment.yaml)
and [Grafana Config](templates/grafana-config.yaml) for information on which environment variables
and which files to provide. It is recommended to use a reverse proxy, to seamlessly connect the
two (or three) components. See [Nginx Deployment](templates/nginx-deployment.yaml)
and [Nginx Config](templates/nginx-config.yaml) for information on which environment variables and
which files to provide.

### Hawk Release

To enable Hawk Release, you have to install [Flux](https://github.com/fluxcd/flux)
and [Flagger](https://github.com/fluxcd/flagger). Then you can configure to use the Metrics using
Prometheus, see [Hawk Service](https://github.com/PrivacyEngineering/hawk-service) for more
information on which mappings to use. You also need to configure Prometheus to scrape the Metrics.

### Hawk Build

To enable Hawk Build you have to install and configure
the [OpenAPI Privacy Changes Service](https://github.com/TUB-CNPE-TB/openapi-privacy-changes-service)
. Then it is possible to
use [OpenAPI Privacy Alert GitHub Action](https://github.com/TUB-CNPE-TB/openapi-privacy-alert-action)
.

## Example

An example using the [WeaveWorks SockShop](https://github.com/microservices-demo/microservices-demo)
, integrated with some of Hawk components can be
found [here](https://github.com/PrivacyEngine/hawk-sockshop).


## Hawk Grafana Dashboard
![Dashboard overview with four panels](./images/dashboard.png "Dashboard overview with four distinct panels")