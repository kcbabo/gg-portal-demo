#!/bin/sh

if [ -z "$CLIENT_ID" ]
then
      printf "\nThe 'CLIENT_ID' environment variable is empty. This environment variable, set to the client-id of your service account which was generated with the 'keycloak.sh script', is required to run this load generation script.\n"
      exit 1
fi

if [ -z "$CLIENT_SECRET" ]
then
      printf "\nThe 'CLIENT_ID' environment variable is empty. This environment variable, set to the client-id of your service account which was generated with the 'keycloak.sh script', is required to run this load generation script.\n"
      exit 1
fi

export KEYCLOAK_URL=http://keycloak.example.com
export REALM=master

export ACCESS_TOKEN=$(curl -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=client_credentials" ${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token| jq .access_token)

printf "Access token=$ACCESS_TOKEN"

printf "Generate API-Key"

# read -r apiKey apiKeyId <<<$(curl -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" -d '{ "apiKeyName": "api-analytics-load-key", "usagePlan": "platinum" }' http://developer.example.com/v1/api-keys|  jq -r '[.apiKey, .id] | @tsv')
read -r apiKey apiKeyId <<<$(curl -k -X POST -d '{ "apiKeyName": "api-analytics-load-key", "usagePlan": "platinum" }' -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${ACCESS_TOKEN}" http://developer.example.com/v1/api-keys |  jq -r '[.apiKey, .id] | @tsv')

printf "\nAPI-Key: $apiKey\n"
printf "API-Key-ID: $apiKeyId\n"

printf "Calling the Tracks API a number of times. This can take a while."
for i in {1..1000}
do
   curl -s -o /dev/null -w "%{http_code}\n" -H "Accept: application/json" -H "api-key: $apiKey" http://api.example.com/trackapi/tracks

   # TODO: Parse the response and loop over all the individual tracks.

done