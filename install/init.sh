#!/bin/bash

source ./env.sh

pushd ../

kubectl create ns backstage
kubectl create ns tracks

kubectl apply -f portal-frontend.yaml
kubectl apply -f policy/api-key.yaml
kubectl apply -f policy/auth-server.yaml
kubectl apply -f policy/rl-server.yaml
kubectl apply -f policy/rl-config.yaml
kubectl apply -f policy/portal-cors.yaml
kubectl apply -f policy/api-cors.yaml

kubectl apply -f keycloak-example-com-rt.yaml
kubectl apply -f developer-example-com-rt.yaml
kubectl apply -f api-example-com-rt.yaml

kubectl apply -f dev-portal.yaml

# API Usage & Analytics

if [ "$API_ANALYTICS_ENABLED" = true ] ; then
  kubectl apply -f misc/dashboards.yaml
  kubectl apply -f misc/grafana.yaml
fi

popd
