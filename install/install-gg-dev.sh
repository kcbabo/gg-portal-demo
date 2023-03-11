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
  --kubecontext $CLUSTER_CTX \
  --version "$GLOO_MESH_VERSION" \
  --chart-file $MESH_CHART_URL \
  --chart-values-file "$CONFIG_DIR/helm-values-gke.yaml" \
  --license $GLOO_GATEWAY_LICENSE_KEY

helm install gloo-agent-addons $AGENT_CHART_URL \
  --namespace gloo-mesh-addons \
  --values "$CONFIG_DIR/addon-values.yaml"


printf "\nWaiting for gloo-mesh-gateways namespace...\n"
until kubectl --context "${CLUSTER_CTX}" get ns gloo-mesh-gateways &>/dev/null; do
  sleep 3
done

printf "Waiting for gateway deployment creation...\n"
until kubectl --context "${CLUSTER_CTX}" get deployment -n gloo-mesh-gateways istio-ingressgateway-1-16 &>/dev/null; do
  sleep 3
done

printf "Waiting for ingress gateway deployment to be ready, this might take a while...\n"
kubectl rollout status deployment --context="${CLUSTER_CTX}" -n gloo-mesh-gateways istio-ingressgateway-1-16 --timeout=5m
printf "Ingress gateway deployment ready!\n\n"

# Create gateway
kubectl --context $CLUSTER_CTX apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: istio-ingressgateway
  namespace: ${GATEWAY_NAMESPACE}
spec:
  listeners:
  - allowedRouteTables:
    - host: www.example.com
    http: {}
    port:
      number: 80
    - host: www.example.com
    http: {}
    port:
      number: 80
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF

sleep 3

GW_IP=$(kubectl get svc --context $CLUSTER_CTX -n gloo-mesh-gateways istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
printf "Ingress gateway IP: %s\n" $GW_IP
echo "export GW_IP=$GW_IP"