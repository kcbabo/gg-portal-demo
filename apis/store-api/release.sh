#!/bin/sh

DOCKER_USER="duncandoyle"

docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag duncandoyle/store-rest-api .
