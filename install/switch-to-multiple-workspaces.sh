#!/bin/sh

pushd ../
# Either create the 4 different workspaces (gateways, keycloak, tracks and petstore), or create the single-default workspace.
########################################################################################
kubectl delete -f workspaces/gg-demo-single-default-workspace.yaml
kubectl delete -f workspaces/gg-demo-single-default-workspacesettings.yaml
########################################################################################
kubectl apply -f workspaces/gateways-workspace.yaml
kubectl apply -f workspaces/gateways-workspacesettings.yaml
kubectl apply -f workspaces/keycloak-workspace.yaml
kubectl apply -f workspaces/keycloak-workspacesettings.yaml
kubectl apply -f workspaces/petstore-workspace.yaml
kubectl apply -f workspaces/petstore-workspacesettings.yaml
kubectl apply -f workspaces/tracks-workspace.yaml
kubectl apply -f workspaces/tracks-workspacesettings.yaml
########################################################################################
popd