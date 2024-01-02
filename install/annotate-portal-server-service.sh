#!/bin/sh
kubectl -n gloo-mesh-addons annotate service gloo-mesh-portal-server \
    gloo.solo.io/scrape-openapi-source=/v1/openapi \
    gloo.solo.io/scrape-openapi-retry-delay="5s" \
    gloo.solo.io/scrape-openapi-pull-attempts="3" \
    gloo.solo.io/scrape-openapi-use-backoff="true"