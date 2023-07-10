#!/bin/bash

pushd ../

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

popd
