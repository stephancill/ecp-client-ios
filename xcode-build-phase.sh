#!/bin/bash

# Xcode Build Phase Script
# This script sets personal configuration for Xcode builds
# Add this as a "Run Script" build phase in Xcode

# Configuration
BUNDLE_ID="co.za.discovexyz.town"
TEAM_ID="PMVY3QQJB8"

# Set environment variables for Xcode build
export PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
export DEVELOPMENT_TEAM="$TEAM_ID"

echo "🔧 Xcode Build Phase: Personal Configuration Applied"
echo "📱 Bundle ID: $BUNDLE_ID"
echo "👥 Team ID: $TEAM_ID"

# This script should be added as a "Run Script" build phase in Xcode
# with "Run script only when installing" checked for device builds
