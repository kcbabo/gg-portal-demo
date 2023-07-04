#!/bin/bash

export GLOO_VERSION=2.4.0-beta2
export ISTIO_REVISION=1-17-2

export CLUSTER_NAME=gg-demo-single
export CLUSTER_CTX=cluster1

export GATEWAY_HOST=api.example.com
export PORTAL_HOST=developer.example.com
export PARTNER_PORTAL_HOST=developer.partner.example.com
export KEYCLOAK_HOST=keycloak.example.com
export GATEWAY_NAMESPACE=gloo-mesh-gateways
export API_ANALYTICS_ENABLED=true
