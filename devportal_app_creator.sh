#!/bin/bash

# Load configuration from config.env
if [ -f "config.env" ]; then
    source config.env
else
    echo "Error: config.env file not found"
    exit 1
fi

# DCR Payload
DCR_PAYLOAD='{
  "callbackUrl":"www.google.lk",
  "clientName":"rest_api_devportal",
  "owner":"admin",
  "grantType":"client_credentials password refresh_token",
  "saasApp":true
}'

# Register Client and append credentials to config.env
echo "Registering client..."
DCR_RESPONSE=$(curl -s -k -X POST -H "Authorization: Basic $BASIC_AUTH" \
                      -H "Content-Type: application/json" \
                      -d "$DCR_PAYLOAD" \
                      "https://$HOST:$SERVLET_PORT/client-registration/v0.17/register")

SUBSCRIBER_CLIENT_ID=$(echo "$DCR_RESPONSE" | jq -r '.clientId')
SUBSCRIBER_CLIENT_SECRET=$(echo "$DCR_RESPONSE" | jq -r '.clientSecret')

if [[ -z "$SUBSCRIBER_CLIENT_ID" || -z "$SUBSCRIBER_CLIENT_SECRET" ]]; then
  echo "Failed to register client."
  exit 1
fi
echo "Client registered successfully!"

# Append the client credentials to config.env
echo "# Subscriber Client Credentials" >> config.env
echo "SUBSCRIBER_CLIENT_ID=$SUBSCRIBER_CLIENT_ID" >> config.env
echo "SUBSCRIBER_CLIENT_SECRET=$SUBSCRIBER_CLIENT_SECRET" >> config.env

# Step 2: Get Access Token
echo "Fetching access token..."
ACCESS_TOKEN_RESPONSE=$(curl -s -k -d "grant_type=password&username=$ADMIN_USERNAME&password=$ADMIN_PASSWORD&scope=$SUBSCRIBER_SCOPE" \
                          -H "Authorization: Basic $(printf "%s" "$SUBSCRIBER_CLIENT_ID:$SUBSCRIBER_CLIENT_SECRET" | base64)" \
                          "https://$HOST:$GATEWAY_PORT/token")

# echo "Access token response.."
# echo "$ACCESS_TOKEN_RESPONSE"

ACCESS_TOKEN=$(echo "$ACCESS_TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Failed to get access token."
  exit 1
fi

echo "Access token received successfully! : $ACCESS_TOKEN"

# Step 3: Create Applications
echo "Creating $NUM_APPS applications..."

for i in $(seq 1 $NUM_APPS); do
  TIMESTAMP=$(date +%s)
  APP_NAME="TestApp_${i}_${TIMESTAMP}"
  
  APP_PAYLOAD='{
    "name": "'"$APP_NAME"'",
    "throttlingPolicy": "Unlimited", 
    "description": "Test application '"$i"'",
    "tokenType": "JWT",
    "groups": [],
    "attributes": {},
    "subscriptionScopes": []
  }'

  echo "Creating application: $APP_NAME"
  APP_RESPONSE=$(curl -s -k -X POST \
                      -H "Authorization: Bearer $ACCESS_TOKEN" \
                      -H "Content-Type: application/json" \
                      -d "$APP_PAYLOAD" \
                      "https://$HOST:$SERVLET_PORT/api/am/store/v1/applications")

  # Check if curl request was successful
  if [[ $? -ne 0 ]]; then
    echo "Failed to create application: $APP_NAME"
    continue
  fi

  APP_ID=$(echo "$APP_RESPONSE" | jq -r '.applicationId')

  # Verify application ID was returned
  if [[ -z "$APP_ID" || "$APP_ID" == "null" ]]; then
    echo "Failed to get application ID from response for: $APP_NAME"
    echo "Response: $APP_RESPONSE"
    continue
  fi

  echo "Application created successfully! Application ID: $APP_ID"
done