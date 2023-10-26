#!/bin/bash

# export GLOO_VERSION=2.4.3
# export DEV_VERSION=false
# export ISTIO_REVISION=1-18-3

# export GLOO_VERSION=2.5.0-beta1
# export DEV_VERSION=false
# export ISTIO_REVISION=1-18-3

export GLOO_VERSION=2.5.0-beta1-2023-10-25-main-ba1c02c66
export DEV_VERSION=true
export ISTIO_REVISION=1-19-1

export CLUSTER_NAME=gg-demo-single
export CLUSTER_CTX=cluster1

export GATEWAY_HOST=api.example.com
export PORTAL_HOST=developer.example.com
export PARTNER_PORTAL_HOST=developer.partner.example.com
export KEYCLOAK_HOST=keycloak.example.com

export KC_ADMIN_PASS=admin
export GATEWAY_NAMESPACE=gloo-mesh-gateways
export API_ANALYTICS_ENABLED=true
export BACKSTAGE_ENABLED=true