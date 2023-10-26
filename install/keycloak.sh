#!/bin/bash

set +x -e
source ./env.sh

export PORTAL_CLIENT_ID=portal-client
export KEYCLOAK_URL=http://$KEYCLOAK_HOST
echo "Keycloak URL: $KEYCLOAK_URL"
export APP_URL=http://$PORTAL_HOST

[[ -z "$KC_ADMIN_PASS" ]] && { echo "You must set KC_ADMIN_PASS env var to the password for a Keycloak admin account"; exit 1;}

# Set the Keycloak admin token
export KEYCLOAK_TOKEN=$(curl -k -d "client_id=admin-cli" -d "username=admin" -d "password=$KC_ADMIN_PASS" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)

[[ -z "$KEYCLOAK_TOKEN" ]] && { echo "Failed to get Keycloak token - check KEYCLOAK_URL and KC_ADMIN_PASS"; exit 1;}

# Register the portal-client
CREATE_PORTAL_CLIENT_JSON=$(cat <<EOM
{
  "clientId": "$PORTAL_CLIENT_ID"
}
EOM
)
read -r regid secret <<<$(curl -k -X POST -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type:application/json" -d "$CREATE_PORTAL_CLIENT_JSON"  ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')

export PORTAL_CLIENT_SECRET=${secret}
export REG_ID=${regid}

[[ -z "$PORTAL_CLIENT_SECRET" || $PORTAL_CLIENT_SECRET == null ]] && { echo "Failed to create client in Keycloak"; exit 1;}

# Create a oauth K8S secret with from the portal-client's secret. 
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-mesh
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${PORTAL_CLIENT_SECRET} | base64)
EOF

# Configure the Portal Client we've just created.
CONFIGURE_PORTAL_CLIENT_JSON=$(cat <<EOM
{
  "publicClient": true, 
  "serviceAccountsEnabled": true, 
  "directAccessGrantsEnabled": true, 
  "authorizationServicesEnabled": true, 
  "redirectUris": [
    "http://developer.example.com/*", 
    "https://developer.example.com/*", 
    "http://localhost:7007/gloo-platform-portal/*", 
    "http://localhost:4000/*", 
    "http://localhost:3000/*"
  ], 
  "webOrigins": ["*"]
}
EOM
)
curl -k -X PUT -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_PORTAL_CLIENT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}

# Add the group attribute in the JWT token returned by Keycloak
CONFIGURE_GROUP_CLAIM_IN_JWT_JSON=$(cat <<EOM
{
  "name": "group", 
  "protocol": "openid-connect", 
  "protocolMapper": "oidc-usermodel-attribute-mapper", 
  "config": {
    "claim.name": "group", 
    "jsonType.label": "String", 
    "user.attribute": "group", 
    "id.token.claim": "true", 
    "access.token.claim": "true"
  }
}
EOM
)
curl -k -X POST -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_GROUP_CLAIM_IN_JWT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models

# Create first user        
CREATE_USER_ONE_JSON=$(cat <<EOM
{
  "username": "user1", 
  "email": "user1@example.com", 
  "enabled": true, 
  "attributes": {
    "group": "users"
  },
  "credentials": [
    {
      "type": "password", 
      "value": "password", "
      temporary": false
    }
  ]
}
EOM
)
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d "$CREATE_USER_ONE_JSON" $KEYCLOAK_URL/admin/realms/master/users

# Create second user
CREATE_USER_TWO_JSON=$(cat <<EOM
{
  "username": "user2",
  "email": "user2@solo.io",
  "enabled": true,
  "attributes": {
    "group": "users"
  }, 
  "credentials": [
    {
      "type": "password",
      "value": "password",
      "temporary": false
    }
  ]
}
EOM
)
curl -k -X POST -H "Authorization: Bearer ${KEYCLOAK_TOKEN}"  -H "Content-Type: application/json" -d "$CREATE_USER_TWO_JSON" $KEYCLOAK_URL/admin/realms/master/users

# Register Portal Service Account Client
export PORTAL_SA_CLIENT_ID=portal-sa
CREATE_PORTAL_SA_CLIENT_JSON=$(cat <<EOM
{ 
  "clientId": "$PORTAL_SA_CLIENT_ID" 
}
EOM
)
read -r regid secret <<<$(curl -k -X POST  -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type:application/json" -d "$CREATE_PORTAL_SA_CLIENT_JSON" ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')

export PORTAL_SA_CLIENT_SECRET=${secret}
export REG_ID=${regid}
[[ -z "$PORTAL_SA_CLIENT_SECRET" || $PORTAL_SA_CLIENT_SECRET == null ]] && { echo "Failed to create client in Keycloak"; exit 1;}

printf "\nCreated service account:\n"
printf "Client-ID: $PORTAL_SA_CLIENT_ID\n"
printf "Client-Secret: $PORTAL_SA_CLIENT_SECRET\n\n"
export CLIENT_ID=$PORTAL_SA_CLIENT_ID
export CLIENT_SECRET=$PORTAL_SA_CLIENT_SECRET

if [ "$BACKSTAGE_ENABLED" = true ] ; then
  printf "\nCreating K8S Secret for PORTAL_SA_CLIENT_SECRET in backstage namespace.\n"
  
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: Secret
  metadata:
    name: portal-sa-client-secret
    namespace: backstage
  type: extauth.solo.io/oauth
  data:
    SA_CLIENT_SECRET: $(echo -n ${PORTAL_SA_CLIENT_SECRET} | base64)
EOF
fi

#Configure the Portal Service Account
CONFIGURE_CLIENT_SERVICE_ACCOUNT_JSON=$(cat <<EOM
{
  "publicClient": false, 
  "standardFlowEnabled": false, 
  "serviceAccountsEnabled": true, 
  "directAccessGrantsEnabled": false, 
  "authorizationServicesEnabled": false
}
EOM
)
curl -k -X PUT  -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_CLIENT_SERVICE_ACCOUNT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}

# Add the group attribute to the JWT token returned by Keycloak
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d "$CONFIGURE_GROUP_CLAIM_IN_JWT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models

# Add the usagePlan attribute to the JWT token returned by Keycloak
CONFIGURE_USAGE_PLAN_CLAIM_IN_JWT_JSON=$(cat <<EOM
{
  "name": "usagePlan", 
  "protocol": "openid-connect", 
  "protocolMapper": 
  "oidc-usermodel-attribute-mapper", 
  "config": {
    "claim.name": "usagePlan", 
    "jsonType.label": "String", 
    "user.attribute": "usagePlan", 
    "id.token.claim": "true", 
    "access.token.claim": "true"
  }
}
EOM
)
curl -k -X POST -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_USAGE_PLAN_CLAIM_IN_JWT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models

# TODO: We should actually loop a couple of times. I.e. retry till the entity is created.
# printf "Wait till the user is created."
# sleep 2

# Retrieve the user-id of the user we've just created.
export userResponse=$(curl -k -X GET -H "Accept:application/json" -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" ${KEYCLOAK_URL}/admin/realms/master/users?username=service-account-${KEYCLOAK_SA_CLIENT_ID}&exact=true)
export userid=$(echo $userResponse | jq -r '.[0].id')
# Set the extra group attribute on the user.

CONFIGURE_GROUP_ATTRIBUTE_ON_USER_JSON=$(cat <<EOM
{
  "email": "${PORTAL_SA_CLIENT_ID}@example.com", 
  "attributes": {
    "group": "users",
    "usagePlan": "silver"
  }
}
EOM
)
curl -k -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d "$CONFIGURE_GROUP_ATTRIBUTE_ON_USER_JSON" $KEYCLOAK_URL/admin/realms/master/users/$userid

#### Creating a second OIDC Client for another portal.

export PARTNER_PORTAL_CLIENT_ID=partner-portal-client
export PARTNER_APP_URL=http://$PARTNER_PORTAL_HOST

# Register the client
CREATE_PARTNER_PORTAL_CLIENT_JSON=$(cat <<EOM
{
  "clientId": "$PARTNER_PORTAL_CLIENT_ID" 
}
EOM
)
read -r regid secret <<<$(curl -k -X POST -H "Authorization: bearer ${KEYCLOAK_TOKEN}" -H "Content-Type:application/json" -d "$CREATE_PARTNER_PORTAL_CLIENT_JSON" ${KEYCLOAK_URL}/realms/master/clients-registrations/default|  jq -r '[.id, .secret] | @tsv')

export PARTNER_PORTAL_CLIENT_SECRET=${secret}
export REG_ID=${regid}

[[ -z "$PARTNER_PORTAL_CLIENT_SECRET" || $PARTNER_PORTAL_CLIENT_SECRET == null ]] && { echo "Failed to create client in Keycloak"; exit 1;}

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: partner-oauth
  namespace: gloo-mesh
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${PARTNER_PORTAL_CLIENT_SECRET} | base64)
EOF

# Configure the Portal Client we've just created.
CONFIGURE_PARTNER_PORTAL_CLIENT_JSON=$(cat <<EOM
{
  "publicClient": true,
  "serviceAccountsEnabled": true,
  "directAccessGrantsEnabled": true,
  "authorizationServicesEnabled": true,
  "redirectUris": [
    "http://developer.example.com/*",
    "https://developer.example.com/*",
    "http://localhost:7007/gloo-platform-portal/*",
    "http://localhost:4000/*",
    "http://localhost:3000/*"
  ],
  "webOrigins": ["*"]
}
EOM
)
curl -k -X PUT -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_PARTNER_PORTAL_CLIENT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}

# Add the group attribute in the JWT token returned by Keycloak
curl -k -X POST -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -H "Content-Type: application/json" -d "$CONFIGURE_GROUP_CLAIM_IN_JWT_JSON" $KEYCLOAK_URL/admin/realms/master/clients/${REG_ID}/protocol-mappers/models


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