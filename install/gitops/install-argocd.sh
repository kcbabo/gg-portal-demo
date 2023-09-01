#!/bin/sh

# Create the argocd namespace if it does not yet exist.
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Custom configmap to disable TlS
kubectl apply -f argocd-cmd-params-cm.yaml

# Set the argocd admin password to `admin`
ARGOCD_ADMIN_PASSWORD=$(argocd account bcrypt --password admin)
kubectl -n argocd patch secret argocd-secret -p "{\"stringData\": {\"admin.password\": \"$ARGOCD_ADMIN_PASSWORD\", \"admin.passwordMtime\": \"'$(date +%FT%T%Z)'\"}}"

# Restart argocd-server
kubectl -n argocd rollout restart deployment argocd-server 

# Add route to argocd.example.com
kubectl apply -f argocd-example-com-rt.yaml