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

3. **Build with personal configuration:**

   ```bash
   # Use the build script for personal development
   ./build-personal.sh

   # Or open in Xcode (may require manual configuration)
   open ecp-client.xcodeproj
   ```

## Environment variables setup

1. **Copy the template file:**

   ```bash
   cp ecp-client/Info.plist.template ecp-client/Info.plist
   ```

2. **Configure your Pinata credentials:**

   - Get your Pinata JWT token from [Pinata Dashboard](https://app.pinata.cloud/)
   - Replace `YOUR_PINATA_JWT_TOKEN_HERE` with your actual JWT token
   - Replace `YOUR_PINATA_GATEWAY_URL_HERE` with your gateway URL

## Documentation

- [SUPPORT.md](SUPPORT.md) - Support information
- [PRIVACY.md](PRIVACY.md) - Privacy policy
