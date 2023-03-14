#!/bin/bash

set +x -e

source ./env.sh

kubectl create ns gloo-mesh || true
kubectl create ns gloo-mesh-addons || true
kubectl label namespace gloo-mesh-addons istio-injection=enabled --overwrite

# Gloo mesh install
BIN_DIR="$(pwd)/.gloo-mesh/bin"
mkdir -p ${BIN_DIR}
MESHCTL_BIN="${BIN_DIR}/meshctl"
rm ${MESHCTL_BIN} || true
wget "https://storage.googleapis.com/gloo-platform-dev/meshctl/${GLOO_MESH_VERSION}/meshctl-darwin-arm64" -O ${MESHCTL_BIN}
chmod +x ${MESHCTL_BIN}

${MESHCTL_BIN} version

${MESHCTL_BIN} install \
  --namespace gloo-mesh \
  --version "$GLOO_MESH_VERSION" \
  --chart-file $MESH_CHART_URL \
  --chart-values-file "helm-values.yaml" \
  --license $GLOO_GATEWAY_LICENSE_KEY

helm install gloo-agent-addons $AGENT_CHART_URL \
  --namespace gloo-mesh-addons \
  --values "addon-values.yaml"


printf "\nWaiting for gloo-mesh-gateways namespace...\n"
until kubectl get ns gloo-mesh-gateways &>/dev/null; do
  sleep 3
done

printf "Waiting for gateway deployment creation...\n"
until kubectl get deployment -n gloo-mesh-gateways istio-ingressgateway-1-16-2 &>/dev/null; do
  sleep 3
done

printf "Waiting for ingress gateway deployment to be ready, this might take a while...\n"
kubectl rollout status deployment -n gloo-mesh-gateways istio-ingressgateway-1-16-2 --timeout=5m
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
      allowedRouteTables:
        - host: ${GATEWAY_HOST}
        - host: ${PORTAL_HOST}
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF

sleep 3

GW_HOST=$(kubectl get svc -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
printf "Ingress gateway IP: %s\n" $GW_HOST
echo "export GW_HOST=$GW_HOST"