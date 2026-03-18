#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
FIRST_NAME="${FIRST_NAME:-Java}"
LAST_NAME="${LAST_NAME:-Backend}"
EMAIL="${EMAIL:-java@backend.local}"
PASSWORD="${PASSWORD:-SecurePassword123!}"
ORG_NAME="${ORG_NAME:-JavaApp}"

require_value() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "Missing required value: $name" >&2
    exit 1
  fi
}

echo "1. Registering user..."
RESPONSE=$(curl -fsS -X POST "$BASE_URL/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "'"$FIRST_NAME"'",
    "lastName": "'"$LAST_NAME"'",
    "email": "'"$EMAIL"'",
    "password": "'"$PASSWORD"'"
  }')

JWT_TOKEN=$(echo "$RESPONSE" | jq -er '.data.token')
require_value "JWT_TOKEN" "$JWT_TOKEN"

echo "2. Creating organization..."
ORG_RESPONSE=$(curl -fsS -X POST "$BASE_URL/v1/organizations" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$ORG_NAME"'"
  }')

ORG_ID=$(echo "$ORG_RESPONSE" | jq -er '.data._id')
require_value "ORG_ID" "$ORG_ID"

echo "3. Switching organization..."
SWITCH_RESPONSE=$(curl -fsS -X POST "$BASE_URL/v1/auth/organizations/$ORG_ID/switch" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json")

ORG_JWT=$(echo "$SWITCH_RESPONSE" | jq -er '.data')
require_value "ORG_JWT" "$ORG_JWT"

echo "4. Fetching environment..."
ENV_RESPONSE=$(curl -fsS -X GET "$BASE_URL/v1/environments" \
  -H "Authorization: Bearer $ORG_JWT")

ENV_ID=$(echo "$ENV_RESPONSE" | jq -er '.data[0]._id')
require_value "ENV_ID" "$ENV_ID"

echo "5. Extracting API key (internal endpoint)..."
API_KEY=$(curl -fsS -X GET "$BASE_URL/v1/environments/api-keys" \
  -H "Authorization: Bearer $ORG_JWT" \
  -H "novu-environment-id: $ENV_ID" \
  | jq -r '.data[0].key')

# In the tested bootstrap flow, the first call above returns null for a
# brand new organization. Regeneration is required to materialize the
# first usable secret key.
if [ "$API_KEY" == "null" ] || [ -z "$API_KEY" ]; then
  echo "API key is null on first bootstrap, forcing regeneration..."
  API_KEY=$(curl -fsS -X POST "$BASE_URL/v1/environments/api-keys/regenerate" \
    -H "Authorization: Bearer $ORG_JWT" \
    -H "novu-environment-id: $ENV_ID" \
    | jq -r '.data[0].key')
fi

require_value "API_KEY" "$API_KEY"

echo "----------------------------------------"
echo "API KEY: $API_KEY"
echo "----------------------------------------"

echo "6. Testing API key..."

curl -fsS -X GET "$BASE_URL/v1/subscribers" \
  -H "Authorization: ApiKey $API_KEY" \
  | jq '.'
