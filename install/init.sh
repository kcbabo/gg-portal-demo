#!/bin/bash

kubectl apply -f policy/auth-server.yaml
kubectl apply -f policy/rl-server.yaml
kubectl apply -f policy/portal-cors.yaml