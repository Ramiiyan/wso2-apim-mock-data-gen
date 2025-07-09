#!/bin/bash

# Load configuration from config.env
if [ -f "config.env" ]; then
    source config.env
else
    echo "Error: config.env file not found"
    exit 1
fi

# Step 2: Get Access Token
echo "Fetching access token..."
ACCESS_TOKEN_RESPONSE=$(curl -s -k -d "grant_type=password&username=$ADMIN_USERNAME&password=$ADMIN_PASSWORD&scope=$PUBLISHER_SCOPE" \
                          -H "Authorization: Basic $(printf "%s" "$PUBLISHER_CLIENT_ID:$PUBLISHER_CLIENT_SECRET" | base64)" \
                          "https://$HOST:$GATEWAY_PORT/token")

echo "Access token response.."
echo "$ACCESS_TOKEN_RESPONSE"
ACCESS_TOKEN=$(echo "$ACCESS_TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Failed to get access token."
  exit 1
fi

echo "Access token received successfully! : $ACCESS_TOKEN"

# Step 3: Get list of APIs
echo "Fetching API list..."
API_LIST_RESPONSE=$(curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" \
                        "https://$HOST:$SERVLET_PORT/api/am/publisher/v1/apis")

# Validate API list response
if ! echo "$API_LIST_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response from API list endpoint"
    echo "Response: $API_LIST_RESPONSE"
    exit 1
fi

echo "API List Response:"
echo "$API_LIST_RESPONSE"

# Extract API IDs into an array
API_IDS=($(echo "$API_LIST_RESPONSE" | jq -r '.list[].id'))

if [[ ${#API_IDS[@]} -eq 0 ]]; then
  echo "No APIs found"
  exit 1
fi

echo "Found ${#API_IDS[@]} APIs:"
for api_id in "${API_IDS[@]}"; do

  # Check lifecycle state for each API
  echo "Checking lifecycle state for API $api_id..."
  LIFECYCLE_STATE_RESPONSE=$(curl -s -k -H "Authorization: Bearer $ACCESS_TOKEN" \
                            "https://$HOST:$SERVLET_PORT/api/am/publisher/v1/apis/$api_id/lifecycle-state")
  
  # Validate lifecycle response
  if ! echo "$LIFECYCLE_STATE_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Invalid JSON response for lifecycle state of API $api_id"
    echo "Response: $LIFECYCLE_STATE_RESPONSE"
    continue
  fi

  echo "Lifecycle state response for API $api_id:"
  echo "$LIFECYCLE_STATE_RESPONSE"
  
  LIFECYCLE_STATE=$(echo "$LIFECYCLE_STATE_RESPONSE" | jq -r '.state')
  
  if [[ "$LIFECYCLE_STATE" == "Published" ]]; then
    echo "API $api_id is already published"
  elif [[ "$LIFECYCLE_STATE" == "Created" ]]; then
    echo "Publishing API $api_id..."
    PUBLISH_RESPONSE=$(curl -k -X POST \
                          -H "Authorization: Bearer $ACCESS_TOKEN" \
                          "https://$HOST:$SERVLET_PORT/api/am/publisher/v1/apis/change-lifecycle?apiId=$api_id&action=Publish")
    
    # Validate publish response
    if ! echo "$PUBLISH_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "Error: Invalid JSON response when publishing API $api_id"
      echo "Response: $PUBLISH_RESPONSE"
      continue
    fi

    if [[ -z "$PUBLISH_RESPONSE" ]]; then
      echo "Failed to publish API $api_id"
    else
      echo "API $api_id published successfully!"
    fi
  else
    echo "API $api_id is in $LIFECYCLE_STATE state"
  fi
done
