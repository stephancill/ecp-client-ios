# Developer Setup Guide

## Personal Development Configuration

This project uses a shared `project.pbxproj` file but allows developers to override specific settings using `UserConfig.xcconfig`.

### Current Shared Settings:

- **Bundle Identifier:** `co.za.stephancill.town`
- **Development Team:** `6JKMV57Y77`

### Your Personal Settings (UserConfig.xcconfig) for example:

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

## Security Setup

### ⚠️ IMPORTANT: Info.plist Configuration

The `Info.plist` file contains sensitive configuration data and should **NEVER** be committed to git.

### Setup Instructions:

1. **Copy the template file:**
   ```bash
   cp ecp-client/Info.plist.template ecp-client/Info.plist
   ```

2. **Configure your Pinata credentials:**
   - Get your Pinata JWT token from [Pinata Dashboard](https://app.pinata.cloud/)
   - Replace `YOUR_PINATA_JWT_TOKEN_HERE` with your actual JWT token
   - Replace `YOUR_PINATA_GATEWAY_URL_HERE` with your gateway URL

3. **Never commit Info.plist:**
   - The file is already in `.gitignore`
   - If you accidentally commit it, immediately revoke and regenerate your JWT token

### Security Notes:

- **JWT tokens are sensitive credentials** - treat them like passwords
- **Never share JWT tokens** in code, logs, or public repositories
- **Revoke compromised tokens** immediately in your Pinata dashboard
- **Use environment variables** for production deployments

### Required Configuration:

- `API_BASE_URL`: Backend API endpoint
- `PINATA_JWT`: Your Pinata JWT token for image uploads
- `PINATA_GATEWAY_URL`: Your Pinata gateway URL for image retrieval

### Emergency Token Revocation

If your JWT token has been exposed:

1. **Immediately revoke the token** in your Pinata dashboard
2. **Generate a new JWT token**
3. **Update your local Info.plist** with the new token
4. **Check git history** to ensure the old token is removed
