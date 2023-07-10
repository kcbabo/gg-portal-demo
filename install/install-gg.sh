#!/bin/bash

set +x -e

source ./env.sh

# Check that required env-vars have been set.
if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]
then
      printf "\nThe 'GLOO_GATEWAY_LICENSE_KEY' environment variable is empty. This environment variable, set to a valid Gloo Gateway License Key, is required to run the installation.\n"
      exit 1
fi

kubectl create ns gloo-mesh || true
kubectl create ns gloo-mesh-addons || true

helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
if [ "$BACKSTAGE_ENABLED" = true ] ; then
  helm repo add ddoyle-gloo-demo https://duncandoyle.github.io/gloo-demo-helm-charts
fi

helm repo update

curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v$GLOO_VERSION sh -
MESH_HOME=$HOME/.gloo-mesh
MESHCTL_BIN=$MESH_HOME/bin
$MESHCTL_BIN/meshctl version

# install CRDs
printf "\nInstalling Gloo Gateway CRDs ...\n"
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
   --namespace=gloo-mesh \
   --create-namespace \
   --version $GLOO_VERSION

GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single.yaml

if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-api-analytics.yaml
  printf "\nInstalling Clickhouse password authentication secret.\n"
  kubectl apply -f clickhouse-auth-secret.yaml
fi

printf "\nUsing Helm values file: $GLOO_GATEWAY_HELM_VALUES_FILE\n."

# install GG with addons
printf "\nInstalling Gloo Gateway ...\n"
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
   --namespace gloo-mesh \
   --version $GLOO_VERSION \
   --values $GLOO_GATEWAY_HELM_VALUES_FILE \
   --set common.cluster=$CLUSTER_NAME \
   --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY


printf "\nWaiting for gloo-mesh-gateways namespace...\n"
until kubectl get ns gloo-mesh-gateways &>/dev/null; do
  sleep 3
done

printf "\nWaiting for gateway deployment creation...\n"
until kubectl get deployment -n gloo-mesh-gateways istio-ingressgateway-$ISTIO_REVISION &>/dev/null; do
  sleep 3
done

printf "Waiting for ingress gateway deployment to be ready, this might take a while...\n"
kubectl rollout status deployment -n gloo-mesh-gateways istio-ingressgateway-$ISTIO_REVISION --timeout=5m
printf "Ingress gateway deployment ready!\n\n"

# Create gateway
kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: istio-ingressgateway
  namespace: ${GATEWAY_NAMESPACE}
spec:
  listeners:
    - http: {}
      port:
        number: 80
      allowedRouteTables:
        - host: api.example.com
        - host: developer.example.com
        - host: developer.partner.example.com
        - host: keycloak.example.com
        - host: grafana.example.com
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF

sleep 3

GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$GW_HOST" ]] && { GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "\nIngress gateway hostame: %s\n" $GW_HOST

pushd ../
printf "\nInstalling Keycloak\n"
kubectl create ns keycloak
#kubectl -n keycloak create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/21.0.2/kubernetes-examples/keycloak.yaml
kubectl -n keycloak create -f misc/keycloak.yaml
kubectl -n keycloak rollout status deploy/keycloak
KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$KC_HOST" ]] && { KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "\nKeycloak service hostname: %s\n\n" $KC_HOST

kubectl apply -f keycloak-example-com-rt.yaml

# API Usage & Analytics
if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  printf "\nAPI Usage & Analytics: Deploying Grafana and Grafana Dashboards.\n"
  kubectl apply -f misc/dashboards.yaml
  kubectl apply -f misc/grafana.yaml
  kubectl apply -f grafana-example-com-rt.yaml
fi
popd

if [ "$BACKSTAGE_ENABLED" = true ] ; then
  printf "\nDeploying Backstage.\n"
  helm upgrade --install gp-portal-demo-backstage ddoyle-gloo-demo/gp-portal-demo-backstage --namespace backstage --create-namespace --version 0.1.0
fi