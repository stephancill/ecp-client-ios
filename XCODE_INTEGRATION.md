# Xcode Integration Guide

This guide shows you how to integrate your personal configuration with Xcode's interface and build onto your phone.

## Method 1: Build Script (Recommended)

### For Simulator:
```bash
# Build for iPhone 15 simulator (default)
./build-personal.sh

# Build for specific simulator
./build-personal.sh -s "iPhone 16 Pro"

# List available simulators
./build-personal.sh -l
```

### For Device:
```bash
# Build for connected device
./build-personal.sh -d
```

## Method 2: Xcode Build Phase Integration

### Step 1: Add Build Phase Script

1. **Open the project in Xcode**
2. **Select the project** in the navigator
3. **Select the "ecp-client" target**
4. **Go to "Build Phases" tab**
5. **Click the "+" button** → "New Run Script Phase"
6. **Name it** "Personal Configuration"
7. **Add this script:**

```bash
# Set personal configuration
export PRODUCT_BUNDLE_IDENTIFIER="co.za.discovexyz.town"
export DEVELOPMENT_TEAM="PMVY3QQJB8"

echo "🔧 Personal Configuration Applied"
echo "📱 Bundle ID: $PRODUCT_BUNDLE_IDENTIFIER"
echo "👥 Team ID: $DEVELOPMENT_TEAM"
```

### Step 2: Configure Build Phase

1. **Check "Run script only when installing"** (for device builds)
2. **Move this phase** to the top of the build phases (before "Compile Sources")
3. **Set "Shell"** to `/bin/bash`

### Step 3: Build in Xcode

Now you can:
- **⌘+B** to build for simulator
- **⌘+R** to run on simulator
- **Product → Destination → Your Device** to build for device

## Method 3: Xcode Scheme Integration

### Step 1: Create Personal Scheme

1. **Product → Scheme → Manage Schemes**
2. **Click "+"** to create new scheme
3. **Name it** "ecp-client-Personal"
4. **Select "ecp-client" target**

### Step 2: Configure Scheme Environment

1. **Select your new scheme**
2. **Click "Edit"**
3. **Go to "Run" tab**
4. **Select "Arguments" tab**
5. **Add Environment Variables:**
   - `PRODUCT_BUNDLE_IDENTIFIER` = `co.za.discovexyz.town`
   - `DEVELOPMENT_TEAM` = `PMVY3QQJB8`

### Step 3: Use Personal Scheme

- **Select your personal scheme** from the scheme dropdown
- **Build and run** normally in Xcode

## Troubleshooting

### Device Build Issues

1. **Check device is connected:**
   ```bash
   ./build-personal.sh -l
   ```

2. **Trust developer certificate:**
   - On your device: Settings → General → VPN & Device Management
   - Trust your developer certificate

3. **Check provisioning profile:**
   - Ensure your Apple Developer account has the correct provisioning profile
   - The bundle ID must match your personal configuration

### Xcode Integration Issues

1. **Build phase not running:**
   - Ensure the script phase is at the top of build phases
   - Check that "Run script only when installing" is appropriate for your use case

2. **Environment variables not set:**
   - Verify the script syntax in the build phase
   - Check that the shell is set to `/bin/bash`

## Quick Commands

```bash
# List all available devices and simulators
./build-personal.sh -l

# Build for iPhone 15 simulator
./build-personal.sh

# Build for iPhone 16 Pro simulator
./build-personal.sh -s "iPhone 16 Pro"

# Build for connected device
./build-personal.sh -d

# Show help
./build-personal.sh -h
```

## Notes

- The build script method is the most reliable for ensuring your personal configuration is used
- Xcode integration methods may require additional setup but provide a more integrated experience
- Always verify your bundle identifier and team ID are correct before building
