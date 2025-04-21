#!/bin/sh

# Check that a Docker tag has been passed.

DOCKER_USER="kcbabo"

printf "\nBuilding 3 Tracks images: version 1.0.0, 1.0.1 and 1.1.0.\n"

printf "\nBuilding Tracks 1.0.0.\n"
cp db-1.0.0.json db.json
cp public/swagger-1.0.json public/swagger.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag kcbabo/tracks-rest-api \
    --tag kcbabo/tracks-rest-api:1.0.0 .

printf "\nBuilding Tracks 1.0.1.\n"
cp db-1.0.1.json db.json
cp public/swagger-1.0.json public/swagger.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag kcbabo/tracks-rest-api \
    --tag kcbabo/tracks-rest-api:1.0.1 .

printf "\nBuilding Tracks 1.1.0.\n"
cp db-1.1.0.json db.json
cp public/swagger-1.1.json public/swagger.json
docker buildx build --push \
    --platform linux/amd64,linux/arm64 \
    --tag kcbabo/tracks-rest-api \
    --tag kcbabo/tracks-rest-api:1.1.0 .

cp db-1.0.0.json db.json
cp public/swagger-1.0.json public/swagger.json