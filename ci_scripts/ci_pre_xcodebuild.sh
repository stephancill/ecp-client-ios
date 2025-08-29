#!/bin/sh
set -euo pipefail

# Get the project root directory
if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  PROJECT_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
else
  # For local development, find the project root relative to this script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

PLIST_TEMPLATE="$PROJECT_ROOT/ecp-client/Info.plist.template"
PLIST="$PROJECT_ROOT/ecp-client/Info.plist"
ENV_FILE="$PROJECT_ROOT/.env"

echo "Using Info.plist template at: $PLIST_TEMPLATE"
echo "Using Info.plist at: $PLIST"
echo "Using .env file at: $ENV_FILE"

# Copy template to create the working Info.plist
if [ -f "$PLIST_TEMPLATE" ]; then
  echo "Copying Info.plist from template..."
  cp "$PLIST_TEMPLATE" "$PLIST"
else
  echo "Error: Info.plist.template not found at $PLIST_TEMPLATE"
  exit 1
fi

if [ ! -f "$PLIST" ]; then
  echo "Error: Could not create Info.plist at $PLIST"
  exit 1
fi

# Function to set plist value
set_plist_value() {
  local key="$1"
  local value="$2"

  if [ -n "$value" ]; then
    echo "Setting $key to: $value"
    /usr/libexec/PlistBuddy -c "Set :$key \"$value\"" "$PLIST" \
    || /usr/libexec/PlistBuddy -c "Add :$key string \"$value\"" "$PLIST"
  else
    echo "$key is not set; skipping"
  fi
}

# Read .env file if it exists
if [ -f "$ENV_FILE" ]; then
  echo "Reading environment variables from .env file..."

  # Read the .env file and export variables
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip empty lines and comments
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z $key ]] && continue

    # Remove quotes from value if present
    value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

    # Export the variable
    export "$key=$value"
  done < "$ENV_FILE"
else
  echo ".env file not found at $ENV_FILE; will use existing environment variables"
fi

# Set values from environment variables (either from .env or CI env vars)
set_plist_value "API_BASE_URL" "${API_BASE_URL:-}"
set_plist_value "PINATA_JWT" "${PINATA_JWT:-}"
set_plist_value "PINATA_GATEWAY_URL" "${PINATA_GATEWAY_URL:-}"

echo "Info.plist update complete"