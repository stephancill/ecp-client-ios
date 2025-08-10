#!/bin/bash

# Build script with personal configuration
# This script sets your personal bundle identifier and development team

echo "Building with personal configuration..."

# Set personal configuration
export PRODUCT_BUNDLE_IDENTIFIER="co.za.discovexyz.town"
export DEVELOPMENT_TEAM="PMVY3QQJB8"

echo "Bundle ID: $PRODUCT_BUNDLE_IDENTIFIER"
echo "Team ID: $DEVELOPMENT_TEAM"

# Build the project
xcodebuild -project ecp-client.xcodeproj -scheme ecp-client -configuration Debug build

echo "Build complete!"
