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
Ingress gateway hostname:
```

These demo instructions assume that you have mapped the IP addresses of this host to `developer.example.com`, `api.example.com`, `keycloak.example.com`, `grafana.example.com` and `argocd.example.com` in /etc/hosts, e.g.
```
1.1.1.1 developer.example.com api.example.com keycloak.example.com grafana.example.com argocd.example.com
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

> **Note**
> the reason for port-forwarding to localhost instead of exposing the UI via the gateway is OAuth/OIDC login flow. Because th DevPortalUI uses "Authorization Code Flow with PKCE", it either needs to run from localhost, or from a secured context, i.e. a HTTPS/TLS protected URL with non-self-signed certificates. Since this would require us to manage certificates, for the purpose of the demo we've decided to run the UI from localhost.


### Backstage
The demo provides a Backstage environment with the Gloo Platform Portal Backstage plugins installed.

The Gloo Platform Portal Backstage back-end plugin requires access to `keycloak.example.com` and `developer.example.com` hosts to acquire an access-token for the portal server and to access the portal server. In this demo we've exposed these hostnames via Gloo Gateway using routetables, and have mapped these hostnames to the Gloo Gateway Ingress ip address. Since the Backstage container in our Kubernetes environment cannot resolve these hostnames, we need to add some mappig rules to the Kubernetes CoreDNS configuration to map these hostnames to the location of the Ingress Gateway. 

Navigate to the `install` directory of the demo, and execute the following script:

```bash
./k8s-coredns-config.sh
```

This will add the following 2 mapping rules to the CoreDNS configuration file:

```
rewrite name keycloak.example.com istio-ingressgateway.gloo-mesh-gateways.svc.cluster.local
rewrite name developer.example.com istio-ingressgateway.gloo-mesh-gateways.svc.cluster.local
```

Restart the Backstage deployment with the following command:
```bash
kubectl -n backstage rollout restart deployment backstage
```

To make the Backstage environment accessible, we port-forward into the backstage service"
```bash
kubectl -n backstage port-forward services/backstage 7007:80
```

> **Note**
> As with the DevPortalUI, the Backstage environment also uses "Authorization Code Flow with PKCE", so it also needs to run from localhost, or from a secured context, i.e. a HTTPS/TLS protected URL with non-self-signed certificates. Since this would require us to manage certificates, for the purpose of the demo we've decided to also run the Backstage UI from localhost.


---

> **Note**
> If you're running this demo on a local Kubernetes cluster like _minikube_, the script might not provide a hostname for the Keycloak service and Ingress gateway. In that case you can, for example, create a tunnel to your cluster with `minikube tunnel` and map your local loopback address (i.e. 127.0.0.1) to the hosts mentioned earlier in /etc/hosts, e.g.
> ```
> 127.0.0.1 developer.example.com api.example.com keycloak.example.com
> ```

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
kubectl apply -f apis/tracks-api-1.0.yaml
```

While the app starts up, let's take a look at the Deployment and Service in the YAML file:

```bash
cat apis/tracks-api-1.0.yaml
```

Notice that there are 2 Deployments defined in this file, one for version 1.0.0 of the service, and one for version 1.0.1, which are both exposed via the same Service version 1.0. This allows us to later in the demo demonstrate a blue-green or canary deployment of our service.

The one thing that is unique about this YAML file is the `gloo.solo.io/scrape-openapi-source` annotation on the `Service` object, which tells the Gloo Platform from where to get the OpenAPI specification of the given service.
If developers don't want to annotate their services, that's fine too. The APIDoc resource can simply be added separetely and you don't need to use discovery.

We can inspect the _Tracks_ service's `swagger.json` specification as follows:

```bash
kubectl -n tracks port-forward services/tracks-rest-api-1-0 5000:5000
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
kubectl -n tracks get apidoc tracks-rest-api-1-0-service -o yaml
```

The APIDoc defines both the API Definition and the destination that serves that API, based on the cluster, namespace, name selectors and a port.

Now that we have the API deployed, we can expose it to the outside world. This is done by creating a `RouteTable`.
The `tracks/tracks-api-rt.yaml` file contains the definition of the `RouteTable` that exposes the _Tracks_ API:

```bash
cat tracks/tracks-api-rt-1.0.yaml
```

The `portalMetadata` field in the `RouteTable` resource allows us to specify additional metadata about our API. The metadata is provided via the Gloo Portal REST API, and from there, can be exposed in the Developer Portal UI. This metadata can include fields like _licence_, _title_, _description_, _service owner_, _data classification_, etc.

The additional metadata will be inlined with the service's Swagger API definition.

Apart from the `portalMetadata` field, this is a standard Gloo Gateway `RouteTable` resource that defines the routing rules.

Note that routes can have `labels`. This mechanism is used to wire in various policies. For example, the `tracks-api` route has the label `usagePlans: dev-portal`. This `usagePlan` is defined in the following `ExtAuthPolicy` and defines:

```bash
cat policy/apikey-api-auth-policy.yaml
```

Observe that the `applyToRoutes` field of this resource states that the routes to which this policy should be applied are the routes that have the `usagePlans: dev-portal` label

Let's apply the `RouteTable` resource:

```bash
kubectl apply -f tracks/tracks-api-rt-1.0.yaml
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
curl -v api.example.com/trackapi/v1.0/tracks
```

#### Security
NOTE: For demo purposes, no security has been enabled on this endpoint/service yet. The API will be secured after we apply the `ExtAuthPolicy`:

```bash
kubectl apply -f policy/apikey-api-auth-policy.yaml
```

When we run the cURL command again, a _401 Unauthorized_ is returned as expected.

```bash
curl -v api.example.com/trackapi/v1.0/tracks
```
```bash
*   Trying 127.0.0.1:80...
* Connected to api.example.com (127.0.0.1) port 80 (#0)
> GET /trackapi/v1.0/tracks HTTP/1.1
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
kubectl -n gloo-mesh get apidoc tracks-rt-1.0-stitched-openapi-gg-demo-single-gloo-mesh-gateways-gg-demo-single -o yaml
```

This schema is stitched from all the `APIDoc` resources that are exposed via a given `RouteTable`. In the case of the _Tracks_ API, this is only a single `APIDoc`.

We can now cURL the REST API definition from the developer portal:

```bash
curl -v developer.example.com/v1/apis/Catstronauts-1.0/schema
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

To apply a rate-limiting policy to our _Tracks_ API, we apply the `policy/rl-policy-apikey.yaml` file. This policy uses labels to apply the policy to routes. In this demo, all routes with the label `usagePlans: dev-portal` will get the policy applies. This includes our _Tracks_ API route.

```bash
kubectl apply -f policy/rl-policy-apikey.yaml
```

We can verify that the policy has been applied to our _Tracks_ API Product by checking the status of the RouteTable:

```bash
kubectl -n gloo-mesh-gateways get routetable tracks-rt-1.0 -o yaml
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
kubectl -n gloo-mesh-gateways patch routetable tracks-rt-1.0 --type "json" -p '[{"op":"add","path":"/metadata/labels/portal-visibility","value":"private"}]'
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


#### API Usage and Analytics

If you've installed the demo with the API Usage and Analytics feature enabled (the default), here is a Grafana dashboard available at `http://grafana.example.com`:

```bash
open http://grafana.example.com
```

Use the username `admin` and password `admin` to login. When asked to change the password, click on `Skip` at the bottom of the modal.

To access the Gloo Platform Portal dashboard, click on the hamburger menu in the top left and click on `Dashoards`. Click on `General` folder icon and click on `API Dashboard`, which will open the Gloo Platform Portal dashboard.

In this dashboard the user can see various metrics and information about the API Products and APIs, including:
* Total Requests
* Total Active Users
* Error Count
* Top API Consumers
* Request Latency
* API Response Status Codes
* etc.

Furthermore, the dashboard contains various powerful filters (top of the screen) that allows a user to select that specific information that they are interested in. 

> **Note**
> The `User ID` filter only shows the first 100 user ids of the top API consumers. This dropdown can be filtered by using `Filter Users` filter to select that specific `User ID` you're interested in, if that id is not in the top 100 API consumers list.

The API Analytics feature is based on the Gloo Gateway/Envoy access logs, and an OpenTelemetry pipeline that receives the access log information and exports it to a Clickhouse datastore. You can inspect the log information used by the API Analytics feature by look at the Gloo Gateway access logs (replace {id} with t):

```bash
kubectl -n gloo-mesh-gateways logs -f deployments/istio-ingressgateway-1-17-2
```

#### GitOps / ArgoCD


##### Installation
These instructions assume that you have the `argocd` CLI installed on your machine. For installation instructions, please consult: https://argo-cd.readthedocs.io/en/stable/cli_installation/

To install Argo CD on our Kubernetes cluster, navigate to  the `install/argocd` directory and run the command:

```bash
./install-argocd.sh
```

This will install a default deployment of ArgoCD, without https and with the username/pasword: admin/admin. Note that this is an insecure setup of Argo CD and only intended for demo purposes. This deployment should not be used in a production environment.

The installation will add a route to Gloo Gateway for the `argocd.example.com` host. During the initial deployment of this demo you should have already added a line to your `/etc/hosts` file that maps the `argocd.example.com` hostname to the ip-address of the ingress gateway.

Navigate to `http://argocd.example.com` and login to the Argo CD console with username `admin` and password `admin`. You should see an empty Argo CD environment.

We can now login to Argo CD with the CLI. From a terminal, login using the following command:

```bash
argocd login argocd.example.com:80
```

You will get a message that the server is not configured with TLS. Enter `y` to proceed. Login with the same username and password combination, i.e. `admin:admin`.

##### Deploying the Petstore APIProduct
> **Note** 
> If you already have the Petstore APIProduct and its services (Pets, Users, Store) deployed to your environment, please remove them.

Once logged in to Argo CD with the CLI, we can deploy our Petstore service using a pre-created Helm chart that can be found [here](https://github.com/DuncanDoyle/gp-portal-demo-petstore-helm-demo). To use this repository, fork it your own GitHub account so you can make updates to the the repository and observe how Argo CD and Helm reconciliate state and deploy your changes to the Kubernetes cluster. After you've forked the repository, run the following command to add this deployment to the Argo CD environment, replacing {GITHUB_USER} with the GitHub account in which you've forked the repository:

```bash
argocd app create petstore-apiproduct --repo https://github.com/{GITHUB_USER}/gp-portal-demo-petstore-helm-demo.git --revision main --path . --dest-namespace default --dest-server https://kubernetes.default.svc --grpc-web
```

Navigate back to the UI and observe that the `petstore-apiproduct` has been added to your Argo CD environment. Notice that the `status` is `out of sync`. Click the `Sync` button in the UI to sync the state of the project with the Kubernetes cluster. In the syncrhonization panel that slides in, click `Synchronize`.

Open a terminal and observe that the Petstore APIProduct has been deployed, including a deployment, service, routetable, etc.:

```bash
kubectl -n default get all
```

```bash
kubectl -n gloo-mesh-gateways get rt petstore-rt -o yaml
```

Observe that Gloo Platform Portal has scraped the services (Pets, Store and User) for their OpenAPI specifications and that a stitched APIDoc has been created for the Petstore API product:

```bash
kubectl get apidoc -A
```

Open the Developer Portal UI (http://localhost:4000), and observe that the PetStore API product has been added to the API catalog.

You can now manage the Petstore APIProduct using a GitOps approach. Simply make a change to the Petstore APIProduct Helm chart in your Git repository, for example add or remove one the services (Pets, Users, Store) from the API Product, push the change to Git and synchronize the state of the application using the `Refresh` and `Sync` buttons in the Argo CD UI.


##### Managing Gloo Platform Portal configuration

Apart from deploying and manager API Products using Argo CD, the Kubernetes native approach of Gloo Platform Portal means that we can manage the entire platform's configuration using GitOps. To demonstrate this, we will show how the Portal's rate-limiting policies and Usage Plans can be maneged with Argo CD.

We have created a Helm chart that configures the Portal's rate-limiting policies. This chart be found [here](https://github.com/DuncanDoyle/gp-portal-platform-team-helm-demo). As with Petstore APIProduct GitOps example, you will need to fork this repository to your own GitHub account so you can make changes to it.

After you've forked the repository, run the following command to add this deployment to the Argo CD environment, replacing {GITHUB_USER} with the GitHub account in which you've forked the repository:

```bash
argocd app create gp-portal-platform-config --repo https://github.com/{GITHUB_USER}/gp-portal-platform-team-helm-demo.git --revision main --path . --dest-namespace default --dest-server https://kubernetes.default.svc --grpc-web
```

Navigate back to the Argo CD UI and observe that the `gp-portal-platform-config` project has been added to your Argo CD environment. Notice that the `status` is `out of sync`. Click the `Sync` button in the UI to sync the state of the project with the Kubernetes cluster. In the syncrhonization panel that slides in, click `Synchronize`.

You can now manage the rate-limit policies and Usage Plans using GitOps. In the forked `gp-portal-platform-team-helm-demo` repository, open the file `templates/policy/rate-limit-server-config.yaml`. Add a `simpleDescriptor` entry that defines the "Diamond" usage plan:

```
- simpleDescriptors:
    - key: userId
    - key: usagePlan
      value: platinum
    rateLimit:
      requestsPerUnit: 10000
      unit: MINUTE
```

Save the file. Next, open the file `templates/dev-portal.yaml` and  add a description for the new Usage Plan:

```
- name: platinum
  description: "The shining usage plan!"
```

Save the file. Commit both the files to your Git repository and push the changes to the origin repository in your GitHub account.

In the Argo CD UI, click on the `Refresh` button of the `gloo-portal-platform-config` project and observe that the status changes to `OutOfSync`. Click on the `Sync` button, and in the panel that slides in, click on `Synchronize`. Your comnfiguration changes are now synchronized with the Kubernetes cluster and your newly configured Usage Plan is available. Go the DevPortal UI and login. When logged in, click on your username and click on `API-Keys`. You should now see your new "Diamond" usage plan with 10000 requests per minute.