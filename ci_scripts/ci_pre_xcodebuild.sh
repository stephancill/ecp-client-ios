#!/bin/sh
set -euo pipefail

PLIST="$CI_PRIMARY_REPOSITORY_PATH/ecp-client/Info.plist"

echo "Using Info.plist at: $PLIST"

if [ ! -f "$PLIST" ]; then
  echo "Error: Info.plist not found at $PLIST"
  exit 1
fi

if [ -n "${API_BASE_URL:-}" ]; then
  echo "Setting API_BASE_URL to: $API_BASE_URL"
  /usr/libexec/PlistBuddy -c "Set :API_BASE_URL \"$API_BASE_URL\"" "$PLIST" \
  || /usr/libexec/PlistBuddy -c "Add :API_BASE_URL string \"$API_BASE_URL\"" "$PLIST"
else
  echo "API_BASE_URL is not set; skipping Info.plist modification"
fi