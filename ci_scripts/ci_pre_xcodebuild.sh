#!/bin/sh
set -euo pipefail

PLIST="$CI_PRIMARY_REPOSITORY_PATH/ecp-client/ecp-client/Info.plist"
if [ -n "${API_BASE_URL:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :API_BASE_URL $API_BASE_URL" "$PLIST" \
  || /usr/libexec/PlistBuddy -c "Add :API_BASE_URL string $API_BASE_URL" "$PLIST"
fi