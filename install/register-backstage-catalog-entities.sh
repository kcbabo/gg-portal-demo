#!/bin/sh

BRANCH="feat/gp-2.4.0.rc5"

curl -v -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
    -d "{\"target\":\"https://github.com/kcbabo/gg-portal-demo/blob/$BRANCH/backstage-catalog-entities/tracks-1.0-catalog-info.yaml\", \"type\":\"url\"}" \
    http://localhost:7007/api/catalog/locations

curl -v -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
    -d "{\"target\":\"https://github.com/kcbabo/gg-portal-demo/blob/$BRANCH/backstage-catalog-entities/tracks-1.1-catalog-info.yaml\", \"type\":\"url\"}" \
    http://localhost:7007/api/catalog/locations

curl -v -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
    -d "{\"target\":\"https://github.com/kcbabo/gg-portal-demo/blob/$BRANCH/backstage-catalog-entities/petstore-catalog-info.yaml\", \"type\":\"url\"}" \
    http://localhost:7007/api/catalog/locations