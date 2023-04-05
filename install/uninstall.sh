#!/bin/bash

set +e +x

source ./env.sh

# clean up Istio resources
kubectl delete GatewayLifecycleManager istio-ingressgateway -n gloo-mesh
kubectl delete IstioLifecycleManager gloo-platform -n gloo-mesh
kubectl delete ns istio-system
kubectl delete ns gloo-mesh-gateways

# uninstall GG
meshctl uninstall
helm uninstall gloo-platform-crds -n gloo-mesh
kubectl delete namespace gloo-mesh
kubectl delete namespace gloo-mesh-addons

# clean up demo resources
kubectl delete ns istio-system gloo-mesh gloo-mesh-addons gloo-mesh-gateways || true

