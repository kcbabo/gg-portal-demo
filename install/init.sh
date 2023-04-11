#!/bin/bash

kubectl create ns tracks

kubectl apply -f portal-frontend.yaml
kubectl apply -f policy/api-key.yaml
kubectl apply -f policy/auth-server.yaml
kubectl apply -f policy/oidc.yaml
kubectl apply -f policy/rl-server.yaml
kubectl apply -f policy/rl-config.yaml
kubectl apply -f policy/portal-cors.yaml
kubectl apply -f portal-all-in-one-rt.yaml