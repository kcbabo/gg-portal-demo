#!/bin/sh

# Setup TLS
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
   -keyout tls.key -out tls.crt -subj "/CN=*"

kubectl -n ${GATEWAY_NAMESPACE} create secret generic tls-secret \
--from-file=tls.key=tls.key \
--from-file=tls.crt=tls.crt

rm tls.key tls.crt

kubectl apply -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualGateway
metadata:
  name: istio-ingressgateway
  namespace: ${GATEWAY_NAMESPACE}
spec:
  listeners:
    - http: {}
      port:
        number: 80
      allowedRouteTables:
        - host: api.example.com
        - host: developer.example.com
        - host: developer.partner.example.com
        - host: keycloak.example.com
    - http: {}
      port:
        number: 443
      tls:
        mode: SIMPLE
        secretName: tls-secret
      allowedRouteTables:
        - host: api.example.com
        - host: developer.example.com
        - host: developer.partner.example.com
        - host: keycloak.example.com
  workloads:
  - selector:
      labels:
        istio: ingressgateway
      cluster: ${CLUSTER_NAME}
EOF
