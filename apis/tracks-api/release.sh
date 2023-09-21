#!/bin/sh

# Check that a Docker tag has been passed.

# if [ -z "$1" ]
# then
#    echo "Please pass a tag that will be used for the Tracks API Docker image as an argument to this script."
#    exit 1
# fi

DOCKER_USER="duncandoyle"

printf "\nBuilding 3 Tracks images: version 1.0.0, 1.0.1 and 1.1.0.\n"

printf "\nBuilding Tracks 1.0.0.\n"
cp db-1.0.0.json db.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag duncandoyle/tracks-rest-api \
    --tag duncandoyle/tracks-rest-api:1.0.0 .

printf "\nBuilding Tracks 1.0.1.\n"
cp db-1.0.1.json db.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag duncandoyle/tracks-rest-api \
    --tag duncandoyle/tracks-rest-api:1.0.1 .

printf "\nBuilding Tracks 1.1.0.\n"
cp db-1.1.0.json db.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag duncandoyle/tracks-rest-api \
    --tag duncandoyle/tracks-rest-api:1.1.0 .

cp db-1.0.0.json db.json