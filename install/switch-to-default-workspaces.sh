#!/bin/sh

pushd ../
# Either create the 4 different workspaces (gateways, keycloak, tracks and petstore), or create the single-default workspace.
########################################################################################
kubectl delete -f workspaces/gateways-workspace.yaml
kubectl delete -f workspaces/gateways-workspacesettings.yaml
kubectl delete -f workspaces/keycloak-workspace.yaml
kubectl delete -f workspaces/keycloak-workspacesettings.yaml
kubectl delete -f workspaces/petstore-workspace.yaml
kubectl delete -f workspaces/petstore-workspacesettings.yaml
kubectl delete -f workspaces/tracks-workspace.yaml
kubectl delete -f workspaces/tracks-workspacesettings.yaml
########################################################################################
kubectl apply -f workspaces/gg-demo-single-default-workspace.yaml
kubectl apply -f workspaces/gg-demo-single-default-workspacesettings.yaml
########################################################################################
popd