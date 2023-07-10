# Gloo Gateway Portal Demo

## Installation

This demo comes with a number of components, including:
* Gloo Platform Portal
* DevPortal UI (front-end)
* Backstage Internal Development Platform
* API Usage and Analytics with OTel and Grafana

The latter two features, Backstage and API Analytics can be enabled/disabled via configuration option in the `./install/env.sh` script. To enable/disable these features, please configure the following environment variables in that script:
```bash
export API_ANALYTICS_ENABLED=false
export BACKSTAGE_ENABLED=false
```
Note that these features enabled by default.

---

This repository comes with a number of installation scripts that allow you to easily deploy this demo to a Kubernetes cluster.

First, we need to to run the `install-gg.sh` script. Note that this step requires you to have a valid Gloo Gateway license key. This will install Gloo Gateway and Portal onto your Kubernetes cluster. It will also download the `meshctl` command line interface.
```bash
# Note: Update `CLUSTER_CTX` var in install/.env 
cd install
export GLOO_GATEWAY_LICENSE_KEY={YOUR_GLOO_GATEWAY_LICENSE_KEY}
./install-gg.sh
```
Note that the install script will print the hostname values of the Ingress gateway, like this:
```
Ingress gateway hostame:
```

These demo instructions assume that you have mapped the IP addresses of this host to `developer.example.com`, `api.example.com`, and `keycloak.example.com` in /etc/hosts, e.g.
```
1.1.1.1 developer.example.com api.example.com keycloak.example.com
```

The installation script also automatically downloads and installs the `meshctl` CLI. To have global access from the command line to this CLI, you should add the directory `$HOME/.gloo-mesh/bin` to your PATH system variable:
```bash
export PATH=$HOME/.gloo-mesh/bin:$PATH
echo $PATH
```

The install script also deploys a Keycloak instance to support OIDC login for the Dev Portal UI and API. We need to set up a client and some users, so run the `keycloak.sh` script to do that.
```bash
./keycloak.sh
```

Next, run the `init.sh` script to pre-provision your environment with some authentication, rate-limit policies, routetables, etc. (see the `init.sh` file for details).
```bash
./init.sh
```

Access Gloo Mesh dashboard using the `meshctl` CLI (make sure you've added the `meshctl` to your PATH system variable):
```bash
meshctl dashboard
```
.... or, via kubectl
```bash
kubectl port-forward -n gloo-mesh svc/gloo-mesh-ui 8090:8090
```
```bash
open http://localhost:8090
```

### DevPortal UI
To access the DevPortalUI (the frontend UI of our Developer Portal), we need to make the service that hosts our developer portal accessible from our local environment. We do this by port-forwarding into the service:
```bash
kubectl -n gloo-mesh-addons port-forward services/portal-frontend 4000
```

**Note**
the reason for port-forwarding to localhost instead of exposing the UI via the gateway is OAuth/OIDC login flow. Because th DevPortalUI uses "Authorization Code Flow with PKCE", it either needs to run from localhost, or from a secured context, i.e. a HTTPS/TLS protected URL with non-self-signed certificates. Since this would require us to manage certificates, for the purpose of the demo we've decided to run the UI from localhost.


### Backstage
The demo provides a Backstage environment with the Gloo Platform Portal Backstage plugin installed. To make the Backstage environment accessible, we port-forward into the backstage service"
```bash
kubectl -n backstage port-forward services/backstage 7007:80
```

**Note**
As with the DevPortalUI, the Backstage environment also uses "Authorization Code Flow with PKCE", so it also needs to run from localhost, or from a secured context, i.e. a HTTPS/TLS protected URL with non-self-signed certificates. Since this would require us to manage certificates, for the purpose of the demo we've decided to also run the Backstage UI from localhost.


---

**Note**
If you're running this demo on a local Kubernetes cluster like _minikube_, the script might not provide a hostname for the Keycloak service and Ingress gateway. In that case you can, for example, create a tunnel to your cluster with `minikube tunnel` and map your local loopback address (i.e. 127.0.0.1) to the hosts mentioned earlier in /etc/hosts, e.g.

```
127.0.0.1 developer.example.com api.example.com keycloak.example.com

```

---

## Story
Individual AppDev teams are developing microservices as APIs (REST, gRPC, GraphQL, etc) and deploying them to Kubernetes.

These APIs can be bundled into API Products which can be exposed to other users and developers for consumption. APIs can be bundled into API Products in multiple ways.
* There can be a 1 on 1 mapping between the API exposed by the service and the API exposed in the API Product.
* The API Product can be a composition of multiple APIs exposed as a single endpoint.

The primitive we use to create an API Product is a `RouteTable`. These `RouteTable`s are then exposed to the outside world through a gateway, or `VirtualGateway`.
We use the concept of _delegated_ `RouteTable` to expose a single host/domain for the API and use delegated routing to route to individual APIs under that domain.

We can expose the Developer Portal on the same host as our APIs, but this can also be a different host. In this demo, the Developer Portal and APIs are exposed via different hosts:
* developer.example.com for the Developer Portal
* api.example.com for the APIs and API Products.

Our `PortalResource` selects the `RouteTables` (or API Products) to be added to the Developer Portal by labels, which forms the configuration that is exposed through our Developer Portal REST API. The front-end Developer Portal UI communicates with the Developer Portal via its REST API server.

The above creates a flexible model in which we can easily implement concepts like segmented internal and external developer portals, or maybe something like a partner developer portal. In these models, multiple Portals can be deployed and mapped to different VirtualGateways. This allows you to map different VirtualGateways to different cloud-provider load-balancers to segment traffic and access. Another option would be to make both portals accessible via a public endpoint and to use an OIDC provider to define different security policies for these different portals. There are many different options and combinations.

---

## Architecture

In this demo, we will deploy the following architecture.

![Alt text](images/gg-portal-demo-image.png?raw=true "GG Portal Demo Architecture")

This architecture shows several different microservices, APIs, Gateways and other components. A brief explanation:

* The black boxes at the bottom of the diagram represent microservices (Tracks, Pets, Users and Store) that expose a RESTful API and its microservice implementation
* The _Track RT_ and _Petstore RT_ represent Gloo `RouteTables`, and, as stated above, are the pimitives we use to create and expose API Products.
* The _Portal_ defines the Gloo Portal, being the Developer Portal that hosts our API Product definitions, in which we can apply API policies like security and rate limiting, and where API Keys can be generated to grant access to our APIs.
* The _api.example.com_ `RouteTable` routes traffic from the `api.example.com` domain to our services.
* The _developer.example.com_ `RouteTable` routes traffic from the `developer.example.com` domain to the Developer Portal.
* The _Virtual Gateway_ exposes our routes to the outside world.

---


## Walkthrough
### Tracks API
In a clean Kubernetes environment, we can show that there are no services yet in the `default` namespace except for the kubernetes API service:

```bash
kubectl get svc
```

We can also show that there are no `apidoc` resources in the cluster and that we're starting from a clean state:

```bash
kubectl get apidocs -A
```

We can now deploy our first service, the _Tracks_ REST API. First, we create the `tracks` namespace:

```bash
kubectl create ns tracks
```

Next, we can deploy the application:

```bash
kubectl apply -f apis/tracks-api.yaml
```

While the app starts up, let's take a look at the Deployment and Service in the YAML file:

```bash
cat apis/tracks-api.yaml
```

The one thing that is unique about this YAML file is the `gloo.solo.io/scrape-openapi-source` annotation on the `Service` object, which tells the Gloo Platform from where to get the OpenAPI specification of the given service.
If developers don't want to annotate their services, that's fine too. The APIDoc resource can simply be added separetely and you don't need to use discovery.

We can inspect the _Tracks_ service's `swagger.json` specification as follows:

```bash
kubectl -n tracks port-forward services/tracks-rest-api 5000:5000
```
```bash
open http://localhost:5000/swagger.json
```
Here we simply port-forward our local port 5000 to the _Tracks_ api service's port 5000, allowing us to access its `http` endpoint.

Since we have annotated the _Tracks_ service with our `gloo.solo.io/scrape-openapi-source` annotation, the service's `swagger.json` file has been discovered and an Gloo `APIDoc` resource has been generated from it:

```bash
kubectl -n tracks get apidoc
```
```bash
kubectl -n tracks get apidoc tracks-rest-api-service -o yaml
```

The APIDoc defines both the API Definition and the destination that serves that API, based on the cluster, namespace, name selectors and a port.

Now that we have the API deployed, we can expose it to the outside world. This is done by creating a `RouteTable`.
The `tracks/tracks-api-rt.yaml` file contains the definition of the `RouteTable` that exposes the _Tracks_ API:

```bash
cat tracks/tracks-api-rt.yaml
```

The `portalMetadata` field in the `RouteTable` resource allows us to specify additional metadata about our API. The metadata is provided via the Gloo Portal REST API, and from there, can be exposed in the Developer Portal UI. This metadata can include fields like _licence_, _title_, _description_, _service owner_, _data classification_, etc.

The additional metadata will be inlined with the service's Swagger API definition.

Apart from the `portalMetadata` field, this is a standard Gloo Gateway `RouteTable` resource that defines the routing rules.

Note that routes can have `labels`. This mechanism is used to wire in various policies. For example, the `tracks-api` route has the label `usagePlans: dev-portal`. This `usagePlan` is defined in the following `ExtAuthPolicy` and defines:

```bash
cat policy/auth-policy.yaml
```

Observe that the `applyToRoutes` field of this resource states that the routes to which this policy should be applied are the routes that have the `usagePlans: dev-portal` label

Let's apply the `RouteTable` resource:

```bash
kubectl apply -f tracks/tracks-api-rt.yaml
```

We can now see the API in the Gloo Platform UI at http://localhost:8090/apis

```bash
open http://localhost:8090/apis/
```

NOTE: The API is only shown in the Gloo Platform UI when it is exposed via a `RouteTable`.

Click on the API to view the details.

The final thing that we need to do to expose our API to the outside world is to connect it to the top-level domain. This can be done with labels and selectors, but in this demo, we use a static configuration.

The `api-example-com-rt.yaml` file defines the `RouteTable` resource that exposes the APIs on `api.example.com` host via the `istio-ingressgateway`.

```bash
cat api-example-com-rt.yaml
```

In the `api-example-rt.yaml` file, if not already done so, uncomment the `/trackapi` matcher and its `delegate` configuration. After you've saved these changes, apply the `RouteTable` resource:

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

When we run the cURL command again, a _401 Unauthorized_ is returned as expected.

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

Later in this demo we will generate the API-key that will grant us access to the API.

---

### Dev Portal

We have deployed our API's using `RouteTables`, but we haven't defined the Developer Portal yet. We can deploy the basic Portal definition via the `dev-portal.yaml` file. It uses a label to define which RouteTables should be exposed via the Developer Portal. In this case, the label is `portal: dev-portal`. This label can for example be found on the `tracks-api-rt.yaml`. In other words: the Portal does not statically define which APIs get exposed; but performs a dynamic selection using labels. Let's deploy the Developer Portal:

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

The Portal automatically creates the `PortalConfig` resources from the existing `APIDoc` resources. In our case, this is the _tracks-api_ doc:

```bash
kubectl get PortalConfig -A
```
```bash
kubectl -n gloo-mesh get PortalConfig developer-portal-gloo-mesh-gg-demo-single -o yaml
```

Note that the APIDoc that is referenced by the PortalConfig is a stitched API:

```bash
kubectl -n gloo-mesh get apidoc tracks-rt-stitched-openapi-gg-demo-single-gloo-mesh-gateways-gg-demo-single -o yaml
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

The example Developer Portal UI is deployed as a Node-based service in our cluster. To access the developer portal UI, open http://localhost:4000 in your browser:

```bash
open http://localhost:4000
```

In the Developer Portal UI we can view all the APIs that have been exposed via our Developer Portal and too which we have access (authentication and authorization flows to be added later).

Click on the _Tracks_ API to get the OpenAPI doc from which you can inspect all the RESTful resources and the operations that the API exposes.

### Backstage
Apart from the Developer Portal UI, the demo also provides a [Backstage](https://backstage.io/) internal developer platform (IDP) environment with the [Gloo Platform Portal Backstage plugin](https://github.com/solo-io/dev-portal-backstage-public#readme) pre-installed. To access the Backstage IDP, open http://localhost:7007 in your browser:

```bash
open http://localhost:7007
```

In the left navigation menu of the Backstage UI, click on `Gloo Portal` to access the Gloo Platform Portal functionality. Like in the DevPortal UI, the Backstage environment allows you to view and explore APIs, try them out using the integrated Swagger UI, view Usage Plans and create and manage API-Keys.


### Pet Store API
We can now deploy an additional API and its microservice to our environment. Like with the _Tracks_ API, this _Pets_ API YAML definition deploys a Kubernetes `deployment` and `service`.

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

Go back to the Dev Portal UI at http://developer.example.com and observe that the _Petstore_ API has been dynamically added to the Dev Portal.

We can now deploy 2 additional APIs, the _User_ API and the _Store_ API. Like with the other APIs, these are implemented as individual microservices. We will add these APIs to our _Petstore_ API Product. Firs we need to deploy the APIs and services:

```bash
kubectl apply -f apis/users-api.yaml
kubectl apply -f apis/store-api.yaml
```

We can now add these 2 services to the `petstore-rt.yaml` `RouteTable` definition, which defines our _Petstore_ API Product. Open the `petstore-rt.yaml` file and uncomment the `user-api` and `store-api` routes. Save the file and re-apply it:

```bash
kubectl apply - f petstore/petstore-rt.yaml
```

Go back to the Dev Portal UI at http://developer.example.com and notice that our _Petstore_ API Product now contains 2 additional RESTful Resources, `/user` and `/store`.


#### Usage Plans

To use our APIs, we will need to create API-keys in order to be able to access them (remember that we had secured our _Tracks_ REST API earlier,  where we got a _401 - Unauthorized_ when we tried to access it). In Gloo Portal, API-keys are bound to _Usage Plans_. A _Usage Plane_ defines a policy or set of policies that the usage of the service. The most common use-case is rate limiting.

In the Dev Portal UI at http://developer.example.com, click on the _Login_ button in the upper right corner. This should bring you to the Keycloak login screen. Login with username `user1` and password `password`. After you've logged in, click on your username in the upper right corner (this should say _User1_) and click on _API Keys_ to navigate to the _API Keys_ screen. You will our 2 APIs listed, _Tracks_ (Catstronauts) and _Petstore_. You can also see that there are zero _Plans_ defined for these APIs, and hence, we cannot yet create any API Keys. So let's first enable the plans for our APIs by applying the rate-limit policies to our API Products/RouteTables.


Gloo implements rate-limiting via _Usage Plans_, which specify the tier of access given to clients. We first need to enable the _Usage Plans_ in our Portal. Open the `dev-portal.yaml` file and uncomment the `usagePlans` configuration section. Save the file and re-apply it:

```bash
kubectl apply -f dev-portal.yaml
```

Refresh the Dev Portal UI. In the _API Usage Plans & Keys_ screen at http://developer.example.com/usage-plans, you will still see zero plans available for both our _Tracks_ and _Petstore_ API. This is because we have on yet applied the required rate-limiting policies to our APIs. Let's apply a policy to our _Tracks_ API.

To apply a rate-limiting policy to our _Tracks_ API, we apply the `policy/rl-policy.yaml` file. This policy uses labels to apply the policy to routes. In this demo, all routes with the label `usagePlans: dev-portal` will get the policy applies. This includes our _Tracks_ API route.

```bash
kubectl apply -f policy/rl-policy.yaml
```

We can verify that the policy has been applied to our _Tracks_ API Product by checking the status of the RouteTable:

```bash
kubectl -n gloo-mesh-gateways get routetable tracks-rt -o yaml
```

In the `status` section of the output, we can see that both the security policy and trafficcontrol policy have been applied:

```
numAppliedRoutePolicies:
    security.policy.gloo.solo.io/v2, Kind=ExtAuthPolicy: 1
    trafficcontrol.policy.gloo.solo.io/v2, Kind=RateLimitPolicy: 1
```

When we now refresg the Dev Portal UI _API Usage Plans & Keys_ screen at http://developer.example.com/usage-plans, we see that there are 3 _Usage Plans_ available for our _Tracks_ (_Catstronauts_) API.


### Private APIs

We have seen that, without being logged in to the Dev Portal UI, we could see all the APIs that were available on the Portal, There can be situations in which you want your public APIs to be seen by any user, whether they're logged into the Portal or not, and other, private APIs, be shielded from users that are not authenticated to the Portal. In that case, we can set an API to "private", and only allow acess to certain users. Let's logout of the Dev Portal UI and explore how we can make some of our APIs private. If you're logged in, click on the logout button in the upper right of the Dev Portal UI,

In the Portal definition, we've already configured a label that allows us to make certain API Products private. Using the `privateAPILabels` configuration, we can configure which labels will mark an API Product/RouteTable as private. In our demo, this label is `portal-visibility: private`, as can be seen in the `dev-portal.yaml` file:

```bash
cat dev-portal.yaml
```

When we apply this configuration to our _Tracks_ API Product/RouteTable, we can see that the product disappears from the Dev Portal UI:

```bash
kubectl -n gloo-mesh-gateways patch routetable tracks-rt --type "json" -p '[{"op":"add","path":"/metadata/labels/portal-visibility","value":"private"}]'
```

Let's login to the Portal to see if we can get access to the _Tracks_ API again. In the Dev Portal UI at http://developer.example.com, click on the _Login_ button in the upper right corner. This should bring you to the Keycloak login screen. Login with username `user1` and password `password`. After succesfully logging in, you should be redirected to the Dev Portal UI. Click on the _APIs_ button in the top-right corner and observe that the _Tracks_ API is still not visible. This is because, when API Products are marked as private, we need define which users can access it. This is done via a `PortalGroup` configuration.

We've provided a pre-configured `PortalGroup` configuration in the demo. Open the file `portal-group.yaml` to see the details:

```bash
cat portal-group.yaml`
```

We can see that users that have a `group` claim in their identity token (JWT) with the value `users` are granted access to the APIs with the label `api: tracks` (which is a label on our _Tracks_ RouteTable). We can also see that these users have access to the `bronze`, `silver` and `gold` plans, and thus can generate API-Keys for them. Let's apply the `PortalGroup` configuration to see if we get access to the _Tracks_ API again.

```bash
kubectl apply -f portal-group.yaml
```

When we look at the Dev Portal UI again, we can see that the _Tracks_ API has appeared again, and we can create API keys for all 3 available plans, `bronze`, `silver` and `gold`.

#### Creating API-Keys

To access our service based on a _Usage Plan_, we need to create an API-Key. Navigate back to the Dev Portal UI _API Usage Plans & Keys_ screen at http://developer.example.com/usage-plans, and expand the _Tracks_/_Catstronaus_ REST API. Add an API-Key to the _Silver Plan (3 Requests per MINUTE)_ by clicking on the _+ ADD KEY_ button. In the _Generate a New Key_ modal that opens, specify the name of your API Key. This can be any name that you would like to use. Click on the _Generate Key_ button. Copy the generated key to a save place. Note the warning that states that this key will only be displayed once. If you loose it, you will not be able to retrieve it and you will have to generate a new one.

With our API Key, we can now access our _Tracks_ REST API again. Call the service using the following `cURL` command, replacing the `{api-key}` placeholder with the API-Key you just generated:

```bash
curl -v -H "api-key:{api-key}" api.example.com/trackapi/tracks
```

Your request will now be properly authenticated and authorized and you will receive a list of tracks from the service.

Our _Usage Plan_ also provides rate-limiting of the requests per API-key. Call the _Tracks_ API a number of times in a row, and observe that after 3 calls per minute your request will be rate-limited and you will receive a _429 - Too Many Requests_ HTTP error from the platform:

```bash
curl -v -H "api-key:{api-key}" api.example.com/trackapi/tracks
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

