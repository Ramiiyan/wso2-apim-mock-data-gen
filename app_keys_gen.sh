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

echo "Application List Response:"
echo "$APP_LIST_RESPONSE"

# Extract application IDs into an array
APP_IDS=($(echo "$APP_LIST_RESPONSE" | jq -r '.list[].applicationId'))

if [[ ${#APP_IDS[@]} -eq 0 ]]; then
  echo "No applications found"
  exit 1
fi

echo "Found ${#APP_IDS[@]} applications"

# Generate keys for each application
for app_id in "${APP_IDS[@]}"; do
  echo "Generating keys for application $app_id..."
  
  # Generate keys for both PRODUCTION and SANDBOX
  for key_type in "PRODUCTION" "SANDBOX"; do
    echo "Generating $key_type keys..."
    
    GENERATE_KEYS_PAYLOAD='{
      "keyType": "'"$key_type"'",
      "grantTypesToBeSupported": [
        "refresh_token",
        "urn:ietf:params:oauth:grant-type:saml2-bearer",
        "password",
        "client_credentials", 
        "iwa:ntlm",
        "urn:ietf:params:oauth:grant-type:device_code",
        "urn:ietf:params:oauth:grant-type:jwt-bearer"
      ],
      "callbackUrl": "",
      "additionalProperties": {},
      "keyManager": "'"$KEY_MANAGER_ID"'",
      "validityTime": 3600,
      "scopes": [
        "am_application_scope",
        "default"
      ]
    }'

    KEYS_RESPONSE=$(curl -s -k -X POST \
                        -H "Authorization: Bearer $ACCESS_TOKEN" \
                        -H "Content-Type: application/json" \
                        -d "$GENERATE_KEYS_PAYLOAD" \
                        "https://$HOST:$SERVLET_PORT/api/am/store/v1/applications/$app_id/generate-keys")

    # Validate keys response
    if ! echo "$KEYS_RESPONSE" | jq -e . >/dev/null 2>&1; then
      echo "Error: Invalid JSON response when generating $key_type keys for application $app_id"
      echo "Response: $KEYS_RESPONSE"
      continue
    fi

    echo "$key_type keys generated successfully for application $app_id"
    echo "Response: $KEYS_RESPONSE"
  done
done
