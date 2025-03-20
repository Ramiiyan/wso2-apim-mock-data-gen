#!/bin/bash

# Load configuration from config.env
if [ -f "config.env" ]; then
    source config.env
else
    echo "Error: config.env file not found"
    exit 1
fi

# Step 1: Get Access Token
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

# Step 3: Get list of applications
echo "Fetching application list..."
APP_LIST_RESPONSE=$(curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" \
                       "https://$HOST:$SERVLET_PORT/api/am/store/v1/applications")

# Validate application list response
if ! echo "$APP_LIST_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from application list endpoint"
    echo "Response: $APP_LIST_RESPONSE"
    exit 1
fi

# echo "Application List Response:"
# echo "$APP_LIST_RESPONSE"

# TESTING
echo "Checking connectivity..."
curl -v -k "https://$HOST:$SERVLET_PORT/api/am/store/v1/apis"

echo "Checking token scopes..."
curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" \
     "https://$HOST:$SERVLET_PORT/oauth2/introspect" \
     -d "token=$ACCESS_TOKEN" -d "client_id=$SUBSCRIBER_CLIENT_ID" \
     -d "client_secret=$SUBSCRIBER_CLIENT_SECRET"

echo "Fetching API list with verbose logging..."
curl -v -k -H "Authorization: Bearer $ACCESS_TOKEN" "https://$HOST:$SERVLET_PORT/api/am/store/v1/apis"

# Step 4: Get list of APIs
echo "Fetching API list..."
API_LIST_RESPONSE=$(curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" \
                        "https://$HOST:$SERVLET_PORT/api/am/store/v1/apis")

# Validate API list response
if ! echo "$API_LIST_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from API list endpoint"
    echo "Response: $API_LIST_RESPONSE"
    exit 1
fi

echo "API List Response:"
echo "$API_LIST_RESPONSE"

# Extract application IDs into an array
APP_IDS=($(echo "$APP_LIST_RESPONSE" | jq -r '.list[].applicationId'))

if [[ ${#APP_IDS[@]} -eq 0 ]]; then
  echo "No applications found"
  exit 1
fi

echo "Found ${#APP_IDS[@]} applications"

# Extract API IDs into an array
API_IDS=($(echo "$API_LIST_RESPONSE" | jq -r '.list[].id'))

if [[ ${#API_IDS[@]} -eq 0 ]]; then
  echo "No APIs found"
  exit 1
fi

echo "Found ${#API_IDS[@]} APIs"

# Create subscription payload for all combinations
echo "Creating subscription payload..."
SUBSCRIPTION_PAYLOAD="["
FIRST=true

for app_id in "${APP_IDS[@]}"; do
    for api_id in "${API_IDS[@]}"; do
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            SUBSCRIPTION_PAYLOAD+=","
        fi
        SUBSCRIPTION_PAYLOAD+=$(cat <<EOF
{
    "applicationId": "$app_id",
    "apiId": "$api_id",
    "throttlingPolicy": "Unlimited",
    "requestedThrottlingPolicy": "Unlimited",
    "status": "UNBLOCKED"
}
EOF
)
    done
done
SUBSCRIPTION_PAYLOAD+="]"

# Make the subscription request
echo "Subscribing to APIs..."
SUBSCRIPTION_RESPONSE=$(curl -s -k \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$SUBSCRIPTION_PAYLOAD" \
    "https://$HOST:$SERVLET_PORT/api/am/store/v1/subscriptions/multiple")

# Check subscription response
if ! echo "$SUBSCRIPTION_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from subscription endpoint"
    echo "Response: $SUBSCRIPTION_RESPONSE"
    exit 1
fi

echo "Subscription process completed!"
echo "Response: $SUBSCRIPTION_RESPONSE"

