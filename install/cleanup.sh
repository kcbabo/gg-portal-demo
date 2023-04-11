#!/bin/bash

kubectl delete -f policy
kubectl delete -f portal-all-in-one-rt.yaml
kubectl delete -f portal-frontend.yaml
kubectl delete -f api-example-com-rt.yaml
kubectl delete -f dev-portal.yaml
kubectl delete -f tracks
kubectl delete -f petstore
kubectl delete -f apis

kubectl delete ns tracks