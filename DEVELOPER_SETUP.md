# Developer Setup Guide

## Personal Development Configuration

This project uses a shared `project.pbxproj` file but allows developers to override specific settings using `UserConfig.xcconfig`.

### Current Shared Settings:
- **Bundle Identifier:** `co.za.stephancill.town`
- **Development Team:** `6JKMV57Y77`

### Your Personal Settings (UserConfig.xcconfig):
- **Bundle Identifier:** `co.za.discovexyz.town`
- **Development Team:** `PMVY3QQJB8`

## How to Use UserConfig.xcconfig

### Option 1: Xcode Configuration (Recommended)

1. **Open the project in Xcode**
2. **Select the project** in the navigator
3. **Select the "ecp-client" target**
4. **Go to "Build Settings" tab**
5. **Click the "+" button** → "Add User-Defined Setting"
6. **Add:** `xcconfig` with value: `UserConfig.xcconfig`

### Option 2: Command Line Override

When building from command line, you can override settings:

```bash
xcodebuild -project ecp-client.xcodeproj \
  -scheme ecp-client \
  -configuration Debug \
  PRODUCT_BUNDLE_IDENTIFIER=co.za.discovexyz.town \
  DEVELOPMENT_TEAM=PMVY3QQJB8
```

### Option 3: Environment Variables

Set environment variables before building:

```bash
export PRODUCT_BUNDLE_IDENTIFIER=co.za.discovexyz.town
export DEVELOPMENT_TEAM=PMVY3QQJB8
xcodebuild -project ecp-client.xcodeproj -scheme ecp-client
```

## Important Notes

- **UserConfig.xcconfig is in .gitignore** - it won't be committed
- **Each developer should create their own** UserConfig.xcconfig
- **The shared project.pbxproj** contains the default team settings
- **Always use your personal bundle identifier** to avoid conflicts

## Troubleshooting

If you get signing errors:
1. Make sure your team ID is correct
2. Ensure your bundle identifier is unique
3. Check that your Apple Developer account has the necessary certificates
