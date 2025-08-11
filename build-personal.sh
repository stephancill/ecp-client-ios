#!/bin/bash

# Build script for personal development
# This script ensures your personal bundle identifier and team ID are used

# Configuration
BUNDLE_ID="co.za.discovexyz.town"
TEAM_ID="PMVY3QQJB8"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --simulator [DEVICE]  Build for simulator (default: iPhone 15)"
    echo "  -d, --device [DEVICE]     Build for connected device"
    echo "  -l, --list-devices        List available devices"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                        # Build for iPhone 15 simulator"
    echo "  $0 -s iPhone 16 Pro       # Build for iPhone 16 Pro simulator"
    echo "  $0 -d                     # Build for connected device"
    echo "  $0 -l                     # List available devices"
}

# Function to list devices
list_devices() {
    echo "📱 Available devices:"
    echo ""
    echo "🔸 Simulators:"
    xcrun simctl list devices available | grep "iPhone\|iPad" | head -10
    echo ""
    echo "🔸 Connected devices:"
    xcrun xctrace list devices 2>/dev/null | grep "iPhone\|iPad" || echo "No connected devices found"
}

# Function to build for simulator
build_simulator() {
    local device=${1:-"iPhone 15"}
    echo "🔧 Building for simulator: $device"
    echo "📱 Bundle ID: $BUNDLE_ID"
    echo "👥 Team ID: $TEAM_ID"
    echo ""
    
    export PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
    export DEVELOPMENT_TEAM="$TEAM_ID"
    
    echo "🚀 Starting build..."
    xcodebuild -project ecp-client.xcodeproj -scheme ecp-client -configuration Debug build -destination "platform=iOS Simulator,name=$device"
}

# Function to build for device
build_device() {
    echo "🔧 Building for connected device"
    echo "📱 Bundle ID: $BUNDLE_ID"
    echo "👥 Team ID: $TEAM_ID"
    echo ""
    
    export PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
    export DEVELOPMENT_TEAM="$TEAM_ID"
    
    echo "🚀 Starting build..."
    xcodebuild -project ecp-client.xcodeproj -scheme ecp-client -configuration Debug build -destination 'generic/platform=iOS'
}

# Parse command line arguments
case "${1:-}" in
    -s|--simulator)
        build_simulator "$2"
        ;;
    -d|--device)
        build_device
        ;;
    -l|--list-devices)
        list_devices
        exit 0
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    "")
        # Default: build for iPhone 15 simulator
        build_simulator "iPhone 15"
        ;;
    *)
        echo "❌ Unknown option: $1"
        show_usage
        exit 1
        ;;
esac

# Check build result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "📱 Your app is ready with personal configuration"
else
    echo ""
    echo "❌ Build failed"
    echo "🔍 Check the error messages above"
fi
