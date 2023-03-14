#!/bin/bash

set +e +x

source ./env.sh

kubectl delete istiolifecyclemanagers -n gloo-mesh gloo-mesh-enterprise || true
kubectl delete gatewaylifecyclemanagers -n gloo-mesh istio-ingressgateway || true

istioctl uninstall --purge -y
#kubectl delete IstioOperator ingress-gateway-16-2 -n gloo-mesh-gateways

meshctl uninstall \
  --namespace gloo-mesh

helm uninstall gloo-agent-addons --namespace gloo-mesh-addons

sleep 10

kubectl delete ns echo istio-system gloo-mesh gloo-mesh-addons gloo-mesh-gateways || true

