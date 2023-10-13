#!/bin/bash

export GLOO_VERSION=2.4.3
export DEV_VERSION=false
# export GLOO_VERSION=2.4.0-2023-09-07-v2.4.x-portal-regex-matching-experimental-fa98dca14
# export DEV_VERSION=true
export ISTIO_REVISION=1-18-3

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