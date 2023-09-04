#!/bin/sh

# Check that a Docker tag has been passed.
if [ -z "$1" ]
then
   echo "Please pass a tag that will be used for the Tracks API Docker image as an argument to this script."
   exit 1
fi

DOCKER_USER="duncandoyle"

docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag duncandoyle/tracks-rest-api \
    --tag duncandoyle/tracks-rest-api:$1 .
