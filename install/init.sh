#!/bin/bash

pushd ../

kubectl create ns tracks
kubectl create ns petstore

# Either create the 4 different workspaces (gateways, keycloak, tracks and petstore), or create the single-default workspace.
########################################################################################
# kubectl apply -f workspaces/gateways-workspace.yaml
# kubectl apply -f workspaces/gateways-workspacesettings.yaml
# kubectl apply -f workspaces/keycloak-workspace.yaml
# kubectl apply -f workspaces/keycloak-workspacesettings.yaml
# kubectl apply -f workspaces/petstore-workspace.yaml
# kubectl apply -f workspaces/petstore-workspacesettings.yaml
# kubectl apply -f workspaces/tracks-workspace.yaml
# kubectl apply -f workspaces/tracks-workspacesettings.yaml
########################################################################################
kubectl apply -f workspaces/gg-demo-single-default-workspace.yaml
kubectl apply -f workspaces/gg-demo-single-default-workspacesettings.yaml
########################################################################################

kubectl apply -f portal-frontend.yaml
kubectl apply -f policy/api-key.yaml
kubectl apply -f policy/auth-server.yaml
kubectl apply -f policy/rl-server.yaml
kubectl apply -f policy/rl-server-config.yaml
kubectl apply -f policy/rl-client-config-apikey.yaml
kubectl apply -f policy/rl-client-config-oauth.yaml
kubectl apply -f policy/portal-cors.yaml
kubectl apply -f policy/api-cors.yaml

kubectl apply -f keycloak-example-com-rt.yaml
kubectl apply -f developer-example-com-rt.yaml
kubectl apply -f api-example-com-rt.yaml

kubectl apply -f dev-portal.yaml

popd
