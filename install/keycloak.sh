#!/bin/bash

set +x -e
source ./env.sh

export KEYCLOAK_CLIENT_ID=portal-client
export KEYCLOAK_URL=http://$KEYCLOAK_HOST
echo "Keycloak URL: $KEYCLOAK_URL"
export APP_URL=http://$PORTAL_HOST

[[ -z "$KC_ADMIN_PASS" ]] && { echo "You must set KC_ADMIN_PASS env var to the password for a Keycloak admin account"; exit 1;}

# Set the Keycloak admin token
export KEYCLOAK_TOKEN=$(curl -k -d "client_id=admin-cli" -d "username=admin" -d "password=$KC_ADMIN_PASS" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

[[ -z "$KEYCLOAK_TOKEN" ]] && { echo "Failed to get Keycloak token - check KEYCLOAK_URL and KC_ADMIN_PASS"; exit 1;}

# Register the client
read -r regid secret <<<$(curl -k -X POST -d "{ \"clientId\": \"${KEYCLOAK_CLIENT_ID}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${KEYCLOAK_TOKEN}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')
export KEYCLOAK_SECRET=${secret}
export REG_ID=${regid}
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"publicClient": true, "serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["http://developer.example.com/*", "https://developer.example.com/*", "http://localhost:7007/gloo-platform-portal/*", "http://localhost:4000/*"], "webOrigins": ["*"]}' $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}

[[ -z "$KEYCLOAK_SECRET" || $KEYCLOAK_SECRET == null ]] && { echo "Faled to create client in Keycloak"; exit 1;}

# Add the group attribute in the JWT token returned by Keycloak
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models

# Create first user                                                                                                                                                                                           
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@example.com", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users

# Create second user
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user2", "email": "user2@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-mesh-addons
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${KEYCLOAK_SECRET} | base64)
EOF

# Register Service Account Client
export KEYCLOAK_SA_CLIENT_ID=portal-sa

read -r regid secret <<<$(curl -k -X POST -d "{ \"clientId\": \"${KEYCLOAK_SA_CLIENT_ID}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${KEYCLOAK_TOKEN}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')
export KEYCLOAK_SA_SECRET=${secret}
export REG_ID=${regid}

printf "\nCreated service account:\n"
printf "Client-ID: $KEYCLOAK_SA_CLIENT_ID\n"
printf "Client-Secret: $KEYCLOAK_SA_SECRET\n\n"
export CLIENT_ID=$KEYCLOAK_SA_CLIENT_ID
export CLIENT_SECRET=$KEYCLOAK_SA_SECRET

curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"publicClient": false, "standardFlowEnabled": false, "serviceAccountsEnabled": true, "directAccessGrantsEnabled": false, "authorizationServicesEnabled": false}' $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}
# Add the group attribute in the JWT token returned by Keycloak
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models

# TODO: We should actually loop a couple of times. I.e. retry till the entity is created.
# printf "Wait till the user is created."
# sleep 2

export userResponse=$(curl -k -X GET -H "Accept:application/json" -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" ${KEYCLOAK_URL}/admin/realms/master/users?username=service-account-${KEYCLOAK_SA_CLIENT_ID}&exact=true)
export userid=$(echo $userResponse | jq -r '.[0].id')
# Set the extra group attribute on the user.
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d "{\"email\": \"${KEYCLOAK_SA_CLIENT_ID}@example.com\", \"attributes\": {\"group\": \"users\"}}" $KEYCLOAK_URL/admin/realms/master/users/$userid


# kubectl apply -f - <<EOF
# apiVersion: security.policy.gloo.solo.io/v2
# kind: ExtAuthPolicy
# metadata:
#   name: oidc-auth
#   namespace: gloo-mesh
# spec:
#   applyToRoutes:
#     - route:
#         labels:
#           oidc-auth-code-flow: "true"
#   config:
#     server:
#       name: ext-auth-server
#       namespace: gloo-mesh-addons
#       cluster: ${CLUSTER_NAME}
#     glooAuth:
#       configs:
#         - oauth2:
#             oidcAuthorizationCode:
#               appUrl: $APP_URL
#               callbackPath: /portal-server/v1/login
#               clientId: ${KEYCLOAK_CLIENT_ID}
#               clientSecretRef:
#                 name: oauth
#                 namespace: gloo-mesh-addons
#               issuerUrl: $KEYCLOAK_URL/realms/master/
#               logoutPath: /portal-server/v1/logout
#               scopes:
#                 - email
#               # you can change the session config to use redis if you want
#               session:
#                 failOnFetchFailure: true
#                 cookie:
#                   allowRefreshing: true
#                 cookieOptions:
#                   notSecure: true
#                   maxAge: 3600
#               headers:
#                 idTokenHeader: id_token
# EOF

#### Creating a second OIDC Client for another portal.

export PARTNER_KEYCLOAK_CLIENT_ID=partner-portal-client
export PARTNER_APP_URL=http://$PARTNER_PORTAL_HOST

# Register the client
read -r regid secret <<<$(curl -k -X POST -d "{ \"clientId\": \"${PARTNER_KEYCLOAK_CLIENT_ID}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${KEYCLOAK_TOKEN}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')
export PARTNER_KEYCLOAK_SECRET=${secret}
export REG_ID=${regid}
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"publicClient": true, "serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["http://developer.example.com/*", "https://developer.example.com/*", "http://localhost:7007/gloo-platform-portal/*", "http://localhost:4000/*"], "webOrigins": ["*"]}' $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}

[[ -z "$PARTNER_KEYCLOAK_SECRET" || $PARTNER_KEYCLOAK_SECRET == null ]] && { echo "Faled to create client in Keycloak"; exit 1;}

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: partner-oauth
  namespace: gloo-mesh-addons
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${PARTNER_KEYCLOAK_SECRET} | base64)
EOF

# kubectl apply -f - <<EOF
# apiVersion: security.policy.gloo.solo.io/v2
# kind: ExtAuthPolicy
# metadata:
#   name: partner-oidc-auth
#   namespace: gloo-mesh
# spec:
#   applyToRoutes:
#     - route:
#         labels:
#           partner-oidc-auth-code-flow: "true"
#   config:
#     server:
#       name: ext-auth-server
#       namespace: gloo-mesh-addons
#       cluster: ${CLUSTER_NAME}
#     glooAuth:
#       configs:
#         - oauth2:
#             oidcAuthorizationCode:
#               appUrl: $PARTNER_APP_URL
#               callbackPath: /portal-server/v1/login
#               clientId: ${PARTNER_KEYCLOAK_CLIENT_ID}
#               clientSecretRef:
#                 name: partner-oauth
#                 namespace: gloo-mesh-addons
#               issuerUrl: $KEYCLOAK_URL/realms/master/
#               logoutPath: /portal-server/v1/logout
#               scopes:
#                 - email
#               # you can change the session config to use redis if you want
#               session:
#                 failOnFetchFailure: true
#                 cookie:
#                   allowRefreshing: true
#                 cookieOptions:
#                   notSecure: true
#                   maxAge: 3600
#               headers:
#                 idTokenHeader: id_token
# EOF