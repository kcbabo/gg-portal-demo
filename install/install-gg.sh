#!/bin/bash

set +x -e

source ./env.sh

# Check that required env-vars have been set.
if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]
then
      echo "The 'GLOO_GATEWAY_LICENSE_KEY' environment variable is empty. This environment variable, set to a valid Gloo Gateway License Key, is required to run the installation."
      exit 1
fi

kubectl create ns gloo-mesh || true
kubectl create ns gloo-mesh-addons || true

helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update

curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v$GLOO_VERSION sh -
MESH_HOME=$HOME/.gloo-mesh
MESHCTL_BIN=$MESH_HOME/bin
$MESHCTL_BIN/meshctl version

# install CRDs
echo "Installing Gloo Gateway CRDs ..."
helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
   --namespace=gloo-mesh \
   --create-namespace \
   --version $GLOO_VERSION

# install GG with addons
echo "Installing Gloo Gateway ..."
helm upgrade --install gloo-platform gloo-platform/gloo-platform \
   --namespace gloo-mesh \
   --version $GLOO_VERSION \
   --values gloo-gateway-single.yaml \
   --set common.cluster=$CLUSTER_NAME \
   --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY


printf "\nWaiting for gloo-mesh-gateways namespace...\n"
until kubectl get ns gloo-mesh-gateways &>/dev/null; do
  sleep 3
done

printf "Waiting for gateway deployment creation...\n"
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

pushd ../misc
printf "\nInstalling Keycloak\n"
kubectl create ns keycloak
#kubectl -n keycloak create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/21.0.2/kubernetes-examples/keycloak.yaml
kubectl -n keycloak create -f keycloak.yaml
kubectl -n keycloak rollout status deploy/keycloak
KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$KC_HOST" ]] && { KC_HOST=$(kubectl -n keycloak get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "\nKeycloak service hostname: %s\n" $KC_HOST
popd