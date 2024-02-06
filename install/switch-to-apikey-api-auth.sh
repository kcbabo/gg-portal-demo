#!/bin/sh

pushd ..

printf "\nRemove OAuth API Auth and Rate Limit policies.\n"
kubectl delete -f policy/oauth-api-auth-policy.yaml
kubectl delete -f policy/rl-policy-oauth.yaml

printf "\nRemove API-Key API Auth and Rate Limit with Dynamic Rate Limiting policies.\n"
kubectl delete -f policy/apikey-api-auth-policy-drl.yaml
kubectl delete -f policy/rl-policy-apikey-drl.yaml

printf "\nApply API-Key API Auth and Rate Limit policies.\n"
kubectl apply -f policy/apikey-api-auth-policy.yaml
kubectl apply -f policy/rl-policy-apikey.yaml

popd