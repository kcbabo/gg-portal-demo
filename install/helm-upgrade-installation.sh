#!/bin/sh

set +x -e

source ./env.sh

if [ "$DEV_VERSION" = true ] ; then
  export MESH_CHART_URL="https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts/gloo-platform-${GLOO_VERSION}.tgz"
fi

if [ "$DEV_VERSION" = false ] ; then
  GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single.yaml
else
  GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-dev.yaml
fi

if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  if [ "$DEV_VERSION" = false ] ; then
    GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-api-analytics.yaml
  else
    GLOO_GATEWAY_HELM_VALUES_FILE=gloo-gateway-single-api-analytics-dev.yaml
  fi
  printf "\nInstalling Clickhouse password authentication secret.\n"
  kubectl apply -f ../misc/clickhouse-auth-secret.yaml
fi

echo "Gloo Version: $GLOO_VERSION"
echo "Gloo Gateway Values File: $GLOO_GATEWAY_HELM_VALUES_FILE"

if [ "$DEV_VERSION" = false ] ; then
  helm upgrade --install gloo-platform gloo-platform/gloo-platform \
    --namespace gloo-mesh \
    --version $GLOO_VERSION \
    --values $GLOO_GATEWAY_HELM_VALUES_FILE \
    --set common.cluster=$CLUSTER_NAME \
    --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY
else
  helm upgrade --install gloo-platform $MESH_CHART_URL \
    --namespace gloo-mesh \
    --values $GLOO_GATEWAY_HELM_VALUES_FILE \
    --set common.cluster=$CLUSTER_NAME \
    --set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY
fi