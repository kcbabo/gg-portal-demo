#!/bin/bash

set +x -e

source ./env.sh

kubectl create ns gloo-mesh || true
kubectl create ns gloo-mesh-addons || true

helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update

curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v$GLOO_VERSION sh -
meshctl version

# install CRDs
echo "Installing Gloo Gateway CRDs ..."
helm install gloo-platform-crds gloo-platform/gloo-platform-crds \
   --namespace=gloo-mesh \
   --create-namespace \
   --version $GLOO_VERSION

# install GG with addons
echo "Installing Gloo Gateway ..."
helm install gloo-platform gloo-platform/gloo-platform \
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
    - port:
        number: 80
      http: {}
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF

sleep 3

GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
printf "Ingress gateway hostame: %s\n" $GW_HOST

printf "Installing Keycloak"
kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/12.0.4/kubernetes-examples/keycloak.yaml
kubectl rollout status deploy/keycloak
KC_HOST=$(kubectl get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[[ -z "$KC_HOST" ]] && { KC_HOST=$(kubectl get svc keycloak -o jsonpath='{.status.loadBalancer.ingress[0].ip}');}
printf "Keycloak service hostame: %s\n" $KC_HOST
