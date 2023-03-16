#!/bin/bash

kubectl delete -f policy
kubectl delete -f developer-example-com-rt.yaml
kubectl delete -f api-example-com-rt.yaml
kubectl delete -f dev-portal.yaml
kubectl delete -f tracks
kubectl delete -f petstore
kubectl delete -f apis