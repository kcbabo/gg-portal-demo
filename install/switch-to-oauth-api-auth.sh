#!/bin/sh

pushd ..

printf "\nRemove API-Key API Auth and Rate Limit policies.\n"
kubectl delete -f policy/apikey-api-auth-policy.yaml
kubectl delete -f policy/rl-policy-apikey.yaml

printf "\nApply OAuth API Auth and Rate Limit policies.\n"
kubectl apply -f policy/oauth-api-auth-policy.yaml
kubectl apply -f policy/rl-policy-oauth.yaml

popd