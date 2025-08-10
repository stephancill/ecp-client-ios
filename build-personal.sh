#!/bin/bash

# Build script for personal development
# This script ensures your personal bundle identifier and team ID are used

echo "🔧 Building with personal configuration..."
echo "📱 Bundle ID: co.za.discovexyz.town"
echo "👥 Team ID: PMVY3QQJB8"
echo ""

# Set environment variables for the build
export PRODUCT_BUNDLE_IDENTIFIER="co.za.discovexyz.town"
export DEVELOPMENT_TEAM="PMVY3QQJB8"

# Build the project
echo "🚀 Starting build..."
xcodebuild -project ecp-client.xcodeproj -scheme ecp-client -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 15'

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "📱 Your app is ready with personal configuration"
else
    echo ""
    echo "❌ Build failed"
    echo "🔍 Check the error messages above"
fi
