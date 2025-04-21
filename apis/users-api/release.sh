#!/bin/sh

DOCKER_USER="kcbabo"

docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag kcbabo/users-rest-api .
