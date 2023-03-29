# gg-portal-demo
Demo repo for Gloo Gateway Portal


## Installation

This demo comes with a number of installation scripts that allow you to easily deploy this demo to a Kubernetes cluster.

First, we need to to run the `install-gg-dev.sh` script. Note that this step requires you to have a valid Glue Gateway license key. This will install the Gloo Gateway onto your Kubernetes cluster. It will also download the `meshctl` command line interface.
```bash
cd install
export GLOO_GATEWAY_LICENSE_KEY={YOUR_GLUE_GATEWAY_LICENSE_KEY}
./install-gg-dev.sh
```

Next, run the `init.sh` script to pre-provision your environment with some authentication, rate-limit policies, etc. (see the `init.sh` file for details). This file needs to be executed from the repo's root directory.
```bash
cd ..
./install/init.sh
```


Access Gloo Mesh dashboard using the `meshctl` CLI:
```bash
./install/.gloo-mesh/bin/meshctl dashboard
```
.... or, via kubectl
```bash
kubectl port-forward -n gloo-mesh svc/gloo-mesh-ui 8090:8090
```
```bash
open http://localhost:8090
```

---

## Story
Individual AppDev teams are developing and contributing services and their APIs (REST, gRPC, GraphQL, etc) and deploying these services and their APIs into Kubernetes.

These APIs are collected and bundled them into so called "API Products". These "API Products" are the APIs that will be exposed to end-customers and users. APIs can be bundled into API Producs in multiple ways.
* There can be a 1 on 1 mapping between the API exposed by the service and the API exposed in the API Product.
* The API product can be a composition of multiple APIs. E.g. a group of microservices that together form an API Product that I want to expose through the Gateway.


The primitive we use to create and API Product is `RouteTable`. These `RouteTables` are then exposed to the outside world through a gateway ... the `VirtualGateway`.
We use the concept of _delegated_ `RouteTables` to expose a single host/domain for the API and use delegated routing to route to individual APIs under that domain.

We can expose the Developer Portal on the same host as our APIs, but this can also be a different host. In this demo, the Developer Portal and APIs are exposed via different hosts:
* developer.example.com for the Developer Poral
* api.example.com for the APIs and API Products.

Our `PortalResource` selects the `RouteTables` (or API Products) to be added to the Developer Portal by label, which forms the configuration that is exposed through our Developer Portal REST API. The front-end Developer Portal UI communicates with the Developer Portal via its REST API server.

The above creates very flexible model in which we can easily implement concepts like segmented internal and external developer portals, or maybe something like a partner developer portal. In these models, multiple Portals can be deployed and mapped to different VirtualGateways. This allows you to map different VirtualGatways to different cloud-provider load-balancers to segment traffic and access. Another option would be to make both portals accessible via a public endpoint, and to use an OIDC provider to define different security policies for these different portals. There are many different options and combinations.

---

## Walkthrough
### Tracks API
In a clean Kubernetes environment, we can show that there are no services in the `default` namespace except for the Kube API service:

```bash
kubectl get svc
```

We can also shwo that there are no `apidoc` resources in the cluster and that we're starting from an clean state:

```bash
kubectl get apidocs -A
```

We can now deploy our first service and API, the _Tracks_ API. First we create the `tracks` namespace:

```bash
kubectl create ns tracks
```

Next we can deploy the actual microservice and API:

```bash
kubectl apply -f apis/tracks-api.yaml
```

We can see that the _Tracks_ API consists of a Kubernetes `deployment` and `service` by inspecting its YAML file:

```bash
cat apis/tracks-api.yaml
```

The one thing that is unique about this YAML file is the `gloo.solo.io/scrape-openapi-source` annotation on the `Service` object, which tells the Gloo Platform from where to get the (Open)API specification of the given service.
If developers don't want to annotate their services, that's fine too. The APIDoc resource can simply be added seperately and you don't need to use discovery.

We can inspect the _Tracks_ service's `swagger.json` specification as follows:

```bash
kubectl -n tracks port-forward services/tracks-rest-api 5000:5000
```
```bash
open http://localhost:5000/swagger.json
```
Here we simply port-forward our local port 5000 to the _Tracks_ api service's port 5000, allowing us to access its `http` endpoint.

Since we have annotated the _Tracks_ service with our `gloo.solo.io/scrape-openapi-source` annotation, the service's `swagger.json` file has been discoverd and an Gloo `APIDoc` resource has been generated from it:

```bash
kubectl -n tracks get apidoc
```
```bash
kubectl -n tracks get apidoc tracks-rest-api-service -o yaml
```

The APIDoc defines both the API Definition, and the destination that serves that API, based on cluster,namespace, name selectors and a port.

Now that we have a service and API deployed, we can expose the service and API to the outside world. This is done by deploying a `RouteTable`.
The `tracks/tracks-api-rt.yaml` file contains the definition of the `RouteTable` that exposes the _Tracks_ service and its API:

```bash
cat track/tracks-api-rt.yaml
```

The `portalMetadata` fiels is a field in the `RouteTable` resource that allows us to specify additional metadata about our API. The metedata is returned via the Gloo Portal REST API, and from there, can be exposed in the Developer Portal UI. This metadata can for example be licesing information, title, description, service owner, data classification, etc.

The additional metadata will be inlined with the service's Swagger API definition.

Apart from the `portalMetadata` field, this is a standard `RouteTable` resource.

Note that routes can have `labels`. This mechanism is used to wire in various policies. For example, the `tracks-api` route has the label `usagePlans: dev-portal`. This `usagePlan` is defined in the following `ExtAuthPolicy` and defines:

```bash
cat policy/auth-policy.yaml
```

Observe that the `applyToRoutes` field of this resources states that the routes to which this policy should be applied are the routes that have the `usagePlans: dev-portal` label

Let's apply the `RouteTable` resource:

```bash
kubectl apply -f tracks/tracks-api-rt.yaml
```

We can now see the API in the Gloo Platform UI at http://localhost:8090/apis

```bash
open http://localhost:8090/apis/
```

NOTE: the API is only show in the Gloo Platform UI when it is exposed via a `RouteTable`.

Click on the API to view the details.

The final thing that we need to do to expose our API to the outside world is to connect it to the top-level domain. This can be done with labels and selectors, but in this demo we use a static configuration.

The `api-example-com-rt.yaml` file defines the `RouteTable` resource that expose the APIs on `api.example.com` host via the `istio-ingressgateway`.

```bash
cat api-example-com-rt.yaml
```

In the `api-example-rt.yaml` file, uncomment the `/trackapi` matcher and its `delegate` configuration. After you've saved these changes, apply the `RouteTable` resource:

```bash
kubectl apply -f api-example-com-rt.yaml
```

We should now be able to cURL that endpoint. Note that you might need to edit your `/etc/hosts` file to map the `api.example.com` domain to the ip-address of your Kubernetes cluster's ingress.

```bash
curl -v api.example.com/trackapi/tracks
```

#### Security
NOTE: For demo purposes, no security has been enabled on this endpoint/service yet. The API will be secured after we apply the `ExtAuthPolicy`:

```bash
kubectl apply -f policy/auth-policy.yaml
```

When we runt the cURL command again, _401 Unauthorized_ is returned"

```bash
curl -v api.example.com/trackapi/tracks
```
```bash
*   Trying 127.0.0.1:80...
* Connected to api.example.com (127.0.0.1) port 80 (#0)
> GET /trackapi/tracks HTTP/1.1
> Host: api.example.com
> User-Agent: curl/7.86.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 401 Unauthorized
< www-authenticate: API key is missing or invalid
< date: Wed, 29 Mar 2023 15:13:04 GMT
< server: istio-envoy
< content-length: 0
<
```

When we run the command with the correct API-key, we get correctly authenticated and authorized to access the service (Note the the API-Key can be found in `policy/api-key.yaml`):

```bash
curl -v -H "api-key:N2YwMDIxZTEtNGUzNS1jNzgzLTRkYjAtYjE2YzRkZGVmNjcy" api.example.com/trackapi/tracks
```

#### Rate Limiting
Another common API Management feature is "rate limiting". Gloo implements rate-limiting via so called _Usage Plans_, which specify the tier of access given to clients. To apply a rate limiting policy to our _Tracks_ API, we apply the `policy/rl-policy.yaml` file. This policy uses labels to apply the policy to routes. In this demo, all routes with the label `usagePlans: dev-portal` will get the policy applies. This includes our _Tracks_ API route.

```bash
kubectl apply -f policy/rl-policy.yaml
```

Note that our API Key has a the `silver` usage plan configured, as can be seen in the `policy/api-key.yaml` file:

```bash
cat policy/api-key.yaml
```

The `silver` usage plan is configured to allow 3 requests per minute, as can be seen in the rate limiting configuration file `policy/rl-config.yaml`:
```bash
cat policy/rl-config.yaml
```

When we now try to access the _Tracks_ API multiple times per minute, we will see that we will get rate limited at the 3rd attempt, and get a _429 Too Many Requests_ error returned:
```bash
curl -v -H "api-key:N2YwMDIxZTEtNGUzNS1jNzgzLTRkYjAtYjE2YzRkZGVmNjcy" api.example.com/trackapi/tracks
```
```bash
*   Trying 127.0.0.1:80...
* Connected to api.example.com (127.0.0.1) port 80 (#0)
> GET /trackapi/tracks HTTP/1.1
> Host: api.example.com
> User-Agent: curl/7.86.0
> Accept: */*
> api-key:N2YwMDIxZTEtNGUzNS1jNzgzLTRkYjAtYjE2YzRkZGVmNjcy
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 429 Too Many Requests
< x-envoy-ratelimited: true
< date: Wed, 29 Mar 2023 14:53:39 GMT
< server: istio-envoy
< content-length: 0
<
```

---

### Dev Portal

We have deployed our API's `RouteTable`, but we haven't defined the DevPortal yet. We can deploy the basic Portal definition via the `dev-portal.yaml` file. It uses a label to define which RouteTables are exposed via the DevPortal. In this case, the label is `portal: dev-portal`. This label can for example be found on the `tracks-api-rt.yaml`. In other words: the Portal does not statically define which APIs get exposed, but performs a dynamic selection using labels. Let's deploy the DevPortal:

```bash
kubectl apply -f dev-portal.yaml
```

We can inspect the status of the `Portal` resource using the following commands:

```bash
kubectl get Portal -A
```
```bash
kubectl -n gloo-mesh-addons get Portal developer-portal -o yaml
```

The Portal automatically creates the `PortalConfig` resources from the existing `APIDoc` resources. In our case this is the _tracks-api_ doc:

```bash
kubectl get PortalConfig -A
```
```bash
kubectl -n gloo-mesh-addons get PortalConfig developer-portal-gloo-mesh-addons-gg-demo-single -o yaml
```

Note that the APIDoc that is referenced by the PortalConfig is a stitched API:

```bash
kubectl -n gloo-mesh-addons get apidoc tracks-rt-stitched-openapi-gg-demo-single-gloo-mesh-gateways-gg-demo-single -o yaml
```

This schema is stitched from all the `APIDoc` resources that are exposed via a given `RouteTable`. In the case of the _Tracks_ API, this is only a single `APIDoc`.

We can now cURL the REST API definition from the developer portal:

```bash
curl -v developer.example.com/v1/apis/tracks-rt-gloo-mesh-gateways-gg-demo-single/schema
```

A list of all APIs exposed via this developer portal can be fetched with the following cURL command:

```bash
curl -v developer.example.com/v1/apis
```

TODO: Provide instructions how to run the developer portal UI application. See: https://github.com/solo-io/dev-portal-starter/ . Use the `live-api` branch instead of `main` for now.

With the Developer Portal UI running, we can access it on http://localhost:4000

```bash
open http://localhost:4000
```

In the Developer Portal UI we can view all the APIs that have been exposed via our Developer Portal and too which we have access (authentication and authorization flows to be added later).
Click on the _Tracks_ API to get the OpenAPI doc from which you can inspect all the RESTful resources and the operations that the API exposes.

NOTE: A login flow has not been implemented yet in this Developer Portal UI Starter application. Once authentication has been implemented,  users have an identity and then can look the usage plans for the APIs and generate API keys.


### Pet Store API
We can now deploy an additional API and its microservice to our environment. Like with the _Tracks_ API, this _Pets_ API YAML definition deploys a Kuberneres `deployment` and `service`.

```bash
kubectl apply -f apis/pets-api.yaml
```

Like with the _Tracks_ API, we can fetch the OpenAPI Swagger definitiion by port-forwarding to the _Pets_ API service and opening the `swagger.json` URL:

```bash
kubectl -n default port-forward services/pets-rest-api 5000:5000
```
```bash
open http://localhost:5000/swagger.json
```

The Gloo Portal discovery mechanism has discovered the `swagger.json` file via the annotation in the _Pets_ API `Service` definition. and a newly generated `APIDoc` document has been added to the environment:

```bash
kubectl get apidocs -A
```

We now have 3 `APIDocs`, one for the _Tracks_ api, one for the _Pets_ api and one _stitched_ api. Every API product (defined by a `RouteTable` resource) gets a stitched API. This becomes important when you have multiple APIs in a single API product. 

NOTE: there is no stitched APIDoc for the _Pets_ API yet, because we're not yet exposing the service via a `RouteTable`, and hence, it's not part of an API Product yet.

With the _Pets_ API and service deployed, we can now add the required `RouteTable` to the platform, which defines the _Petstore_ API Product:

```bash
kubectl apply -f petstore/petstore-rt.yaml
```

To make the _Petstore_ API Product accessible to the outside world, we also need to connect it to the top-level domain. Open the `api-example-com-rt.yaml` file again and uncomment the `/petstore` matcher and its `delegate` configuration. After you've saved these changes, re-apply the `RouteTable` resource:

```bash
kubectl apply -f api-example-com-rt.yaml
```

Go back to the Dev Portal UI at http://localhost:4000 and observe that the _Petstore_ API has been dynamically added to the Dev Portal.

We can now deploy 2 additional APIs, the _User_ API and the _Store_ API. Like with the other APIs, these are implemented as individual microservices. We will add these APIs to our _Petstore_ API Product. Firs we need to deploy the APIs and services:

```bash
kubectl apply -f apis/users-api.yaml
kubectl apply -f apis/store-api.yaml
```

We can now add these 2 services to the `petstore-rt.yaml` `RouteTable` definition, which defines our _Petstore_ API Product. Open the `petstore-rt.yaml` file and uncomment the `user-api` and `store-api` routes. Save the file and re-apply it:

```bash
kubectl apply - f petstore/petstore-rt.yaml
```

Go back to the Dev Portal UI at http://localhost:4000 and notice that our _Petstore_ API Product now contains 2 additional RESTful Resources, `/user` and `/store`.