#!/bin/bash

#export VERSION_ID=2.3.0-beta1-2023-03-07-jhawley-view-schema-ee8abff73
export VERSION_ID=2.3.0-beta2-2023-03-13-main-d9695cf7a
export GLOO_MESH_VERSION="v${VERSION_ID}"

export REPO=us-docker.pkg.dev/gloo-mesh/istio-7a97385594af
export ISTIO_IMAGE=1.16.2-solo
export REVISION=1-16

export MESH_CHART_URL="https://storage.googleapis.com/gloo-platform-dev/helm-charts/gloo-mesh-enterprise/gloo-mesh-enterprise-${VERSION_ID}.tgz"
export AGENT_CHART_URL="https://storage.googleapis.com/gloo-platform-dev/helm-charts/gloo-mesh-agent/gloo-mesh-agent-${VERSION_ID}.tgz"

export CLUSTER_NAME=gg-demo-single
export CLUSTER_CTX=cluster1
export CLUSTER_REGION="us-central1"
export CLUSTER_ZONE="us-central1-a"

export GATEWAY_HOST=api.example.com
export PORTAL_HOST=developer.example.com
export GATEWAY_NAMESPACE=gloo-mesh-gateways
