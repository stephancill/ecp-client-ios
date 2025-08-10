# town - a new town square

town is an iOS app that lets you post comments to the Ethereum Comments Protocol.

## Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Apple Developer Account (for device testing)

### Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd town-ios2
   ```

2. **Configure your development environment:**
   - See [DEVELOPER_SETUP.md](DEVELOPER_SETUP.md) for personal configuration
   - See [SECURITY_SETUP.md](SECURITY_SETUP.md) for security configuration

3. **Open in Xcode:**
   ```bash
   open ecp-client.xcodeproj
   ```

## Security Setup

### ⚠️ CRITICAL: Info.plist Configuration

The `Info.plist` file contains sensitive configuration data and should **NEVER** be committed to git.

### Quick Setup:

1. **Copy the template file:**
   ```bash
   cp ecp-client/Info.plist.template ecp-client/Info.plist
   ```

2. **Configure your Pinata credentials:**
   - Get your Pinata JWT token from [Pinata Dashboard](https://app.pinata.cloud/)
   - Replace `YOUR_PINATA_JWT_TOKEN_HERE` with your actual JWT token
   - Replace `YOUR_PINATA_GATEWAY_URL_HERE` with your gateway URL

3. **Never commit Info.plist** - it's already in `.gitignore`

### Security Notes:

- **JWT tokens are sensitive credentials** - treat them like passwords
- **Never share JWT tokens** in code, logs, or public repositories
- **Revoke compromised tokens** immediately in your Pinata dashboard

## Developer Setup

### Personal Configuration

This project uses a shared `project.pbxproj` file but allows developers to override specific settings using `UserConfig.xcconfig`.

### Current Shared Settings:
- **Bundle Identifier:** `co.za.stephancill.town`
- **Development Team:** `6JKMV57Y77`

### Setup Your Personal Settings:

1. **Copy the template:**
   ```bash
   cp ecp-client/UserConfig.xcconfig.template ecp-client/UserConfig.xcconfig
   ```

2. **Edit UserConfig.xcconfig** with your personal values:
   - `PRODUCT_BUNDLE_IDENTIFIER = com.yourname.town`
   - `DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE`

3. **Configure in Xcode** (see [DEVELOPER_SETUP.md](DEVELOPER_SETUP.md) for details)

## Documentation

- [DEVELOPER_SETUP.md](DEVELOPER_SETUP.md) - Detailed developer configuration
- [SECURITY_SETUP.md](SECURITY_SETUP.md) - Security configuration and best practices
- [SUPPORT.md](SUPPORT.md) - Support information
- [PRIVACY.md](PRIVACY.md) - Privacy policy
