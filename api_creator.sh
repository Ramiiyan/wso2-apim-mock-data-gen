#!/bin/bash

# Load configuration from config.env
if [ -f "config.env" ]; then
    source config.env
else
    echo "Error: config.env file not found"
    exit 1
fi

CSV_FILE="apis.csv"

# DCR Payload
DCR_PAYLOAD='{
  "callbackUrl":"www.google.lk",
  "clientName":"public_api_publisher",
  "owner":"admin",
  "grantType":"client_credentials password refresh_token",
  "saasApp":true
}'

# echo $BASIC_AUTH
# Step 1: Register Client
echo "Registering client..."
DCR_RESPONSE=$(curl -s -k -X POST -H "Authorization: Basic $BASIC_AUTH" \
                      -H "Content-Type: application/json" \
                      -d "$DCR_PAYLOAD" \
                      "https://$HOST:$SERVLET_PORT/client-registration/v0.17/register")

# echo "$DCR_RESPONSE"

PUBLISHER_CLIENT_ID=$(echo "$DCR_RESPONSE" | jq -r '.clientId')
PUBLISHER_CLIENT_SECRET=$(echo "$DCR_RESPONSE" | jq -r '.clientSecret')

if [[ -z "$PUBLISHER_CLIENT_ID" || -z "$PUBLISHER_CLIENT_SECRET" ]]; then
  echo "Failed to register client."
  exit 1
fi
echo "Client registered successfully!"

# Append the client credentials to config.env
echo "# Publisher Client Credentials" >> config.env
echo "PUBLISHER_CLIENT_ID=$PUBLISHER_CLIENT_ID" >> config.env
echo "PUBLISHER_CLIENT_SECRET=$PUBLISHER_CLIENT_SECRET" >> config.env

# Step 2: Get Access Token
echo "Fetching access token..."
ACCESS_TOKEN_RESPONSE=$(curl -s -k -d "grant_type=password&username=$ADMIN_USERNAME&password=$ADMIN_PASSWORD&scope=$PUBLISHER_SCOPE" \
                          -H "Authorization: Basic $(printf "%s" "$PUBLISHER_CLIENT_ID:$PUBLISHER_CLIENT_SECRET" | base64)" \
                          "https://$HOST:$GATEWAY_PORT/token")

# echo "Access token response.."
# echo "$ACCESS_TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo "$ACCESS_TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Failed to get access token."
  exit 1
fi

echo "Access token received successfully! : $ACCESS_TOKEN"

# Step 3: Read CSV and Create APIs
echo "Reading API details from $CSV_FILE..."
while IFS=',' read -r API_NAME CONTEXT ENDPOINT; do
  # Skip header line
  if [[ "$API_NAME" == "API_Name" ]]; then
    continue
  fi

  echo "Creating API: $API_NAME with context /$CONTEXT"
  
  API_PAYLOAD='{
    "name": "'"$API_NAME"'",
    "description": "Public API - '"$API_NAME"'",
    "context": "/'"$CONTEXT"'",
    "version": "1.0.0",
    "provider": "admin",
    "lifeCycleStatus": "CREATED",
    "responseCachingEnabled": true,
    "cacheTimeout": 300,
    "transport": ["http", "https"],
    "tags": ["public", "api"],
    "policies": ["Unlimited"],
    "apiThrottlingPolicy": "Unlimited",
    "authorizationHeader": "Authorization",
    "securityScheme": ["oauth2"],
    "maxTps": {"production": 1000, "sandbox": 1000},
    "visibility": "PUBLIC",
    "endpointConfig": {
      "endpoint_type": "http",
      "sandbox_endpoints": {"url": "'"$ENDPOINT"'"},
      "production_endpoints": {"url": "'"$ENDPOINT"'"}
    },
    "operations": [
      {
        "target": "/",
        "verb": "GET",
        "authType": "Application & Application User",
        "throttlingPolicy": "Unlimited"
      }
    ]
  }'

  API_RESPONSE=$(curl -s -k -X POST -H "Authorization: Bearer $ACCESS_TOKEN" \
                        -H "Content-Type: application/json" \
                        -d "$API_PAYLOAD" \
                        "https://$HOST:$SERVLET_PORT/api/am/publisher/v1/apis")

  echo "API Creation Response: $API_RESPONSE"
  
  API_ID=$(echo "$API_RESPONSE" | jq -r '.id')

  if [[ -z "$API_ID" || "$API_ID" == "null" ]]; then
    echo "Failed to create API: $API_NAME"
  else
    echo "API created successfully! API ID: $API_ID"
  fi
done < "$CSV_FILE"