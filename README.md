# town

town is an iOS app that lets you post comments to the Ethereum Comments Protocol. Join the testflight https://t.me/+xs2OaEu_928yZTI0

## Stack

A SwiftUI iOS app and Bun + Hono backend for the Ethereum Comments Protocol (ECP).

- The iOS app lets you browse posts, compose replies, and receive push notifications for replies and reactions.
- The backend provides SIWE auth, device registration, notification fanout via APNs, an on-chain listener, and background workers.

## Quick Start

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Apple Developer Account (for device testing)

### Setup

1. **Clone the repository:**

   ```bash
   git clone <repository-url>
   cd ecp-client
   ```

2. **Configure your development environment:**

   - See [DEVELOPER_SETUP.md](DEVELOPER_SETUP.md) for personal configuration
   - See [SECURITY_SETUP.md](SECURITY_SETUP.md) for security configuration

3. **Configure environment variables:**

   ```bash
   # Copy the environment template
   cp .env.example .env

   # Edit .env with your personal values
   # API_BASE_URL=http://localhost:3000
   # PINATA_JWT=your_pinata_jwt_token
   # PINATA_GATEWAY_URL=https://gateway.pinata.cloud
   ```

4. **Build the app:**

   ```bash
   # Open in Xcode - Info.plist is generated automatically during build
   open ecp-client.xcodeproj

   # Or use the build script for personal development
   ./build-personal.sh
   ```

   The build process automatically generates `Info.plist` from the template with your environment variables.

## Environment Variables Setup

The app automatically generates `Info.plist` from a template during the build process, allowing each developer to have their own configuration without modifying shared files.

### For Local Development

1. **Create your environment file:**

   ```bash
   cp .env.example .env
   ```

2. **Configure your values in `.env`:**

   ```bash
   # API Base URL for the backend
   API_BASE_URL=http://localhost:3000

   # Pinata JWT token for image uploads
   PINATA_JWT=your_pinata_jwt_token_here

   # Pinata Gateway URL for image serving
   PINATA_GATEWAY_URL=https://gateway.pinata.cloud
   ```

3. **Build the app:**

   The build process automatically generates `Info.plist` from the template with your environment variables.

### For CI/CD

Set environment variables in your CI system:

```bash
export API_BASE_URL=https://api.production.com
export PINATA_JWT=production_jwt_token
export PINATA_GATEWAY_URL=https://gateway.pinata.cloud
```

The build script will use these values instead of the `.env` file.

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

3. **Configure in Xcode**

4. **Open the project in Xcode**
5. **Select the project** in the navigator
6. **Select the "ecp-client" target**
7. **Go to "Build Settings" tab**
8. **Click the "+" button** → "Add User-Defined Setting"
9. **Add:** `xcconfig` with value: `UserConfig.xcconfig`

## Repository structure

- `ecp-client/` — iOS app (SwiftUI)
  - `ecp-client.xcodeproj` — Xcode project
  - `ecp-client/` — app source
  - Key files:
    - `ecp_clientApp.swift` — app entry; bootstraps auth, notifications, deep links
    - `ContentView.swift` — main feed, compose FAB, settings & notifications sheets
    - `ComposeCommentView.swift` — compose/reply UI, identity/approval checks, balance guard
    - `NotificationsView.swift` — in-app notification center with grouping and deep links
    - `AuthService.swift` — SIWE auth using app key; JWT stored in Keychain
    - `NotificationService.swift` — permission flow, APNs registration, event history, unread badge
    - `DeepLinkService.swift` — app routes and handling notification payloads & custom URLs
    - `CommentsService.swift` — fetch main feed, pagination, pull-to-refresh
    - `CommentManager.swift` — ECP contract structures and helpers (posting, approvals, gas est.)
    - `WalletConfigurationService.swift` — CoinbaseWalletSDK host/callback configuration
    - `AppConfiguration.swift` — reads `API_BASE_URL` from `Info.plist` or env
- `api/` — Bun + Hono backend
  - Hono HTTP server, Prisma/Postgres, BullMQ (Redis), APNs, on-chain listener
  - See `api/README.md` for detailed setup and API reference

## iOS app features

- Feed and details
  - Infinite scroll, pull-to-refresh, skeleton loading
  - Comment rows with reactions and reply counts
  - Detail sheets via deep link routing
- Compose & reply
  - Identity/approval checks with clear guidance when not configured
  - Reply context preview; character count and validation
  - Balance warning + quick link to settings
- Notifications
  - Foreground alert handling and unread badge
  - In-app notification center: server-side history with pagination
  - Reaction aggregation (e.g., "Alice and 3 others liked your post"), avatar rows
  - Taps deep link to the relevant post or parent thread
  - Post subscriptions: enable notifications when a specific user posts (toggle via bell icon on their profile)
- Authentication
  - SIWE: request nonce, sign message locally, verify, and store JWT in Keychain
  - Auto re-auth on 401; token validation on launch
- Push registration
  - Permission prompts, Settings fallback, register/unregister current device
  - Server status check (`/api/notifications/status`) and test send
- Deep linking
  - Custom scheme: `ecp-client://comment/<id>`
  - Notification payload keys supported: `type` (`reply|reaction|mention|...`), `commentId`, `parentId`
- Wallet config
  - Configures `CoinbaseWalletSDK` host and callback URL; app restart if wallet host changes

## Backend features (api/)

- Auth (SIWE)
  - Issue nonce, verify signature, set JWT cookie (`auth`), `/api/auth/me`
  - JWT also accepted via `Authorization: Bearer <token>`
- Notifications service
  - Register/remove device tokens; list and status endpoints
  - Send test notification; persist notification events for in-app feed
  - APNs via token-based auth; invalid token cleanup
  - Post subscriptions: subscribe/unsubscribe to author posts; fanout notifications to subscribers
- Background processing
  - `comments` worker: reacts to on-chain comments, notifies parent on reply/reaction, mentions
  - `notifications` worker: fans out to approved app accounts with registered devices
  - On-chain listener watches `CommentManager` on Base and enqueues jobs
- Data model (Prisma)
  - `User` (id = app address), `NotificationDetails` (device tokens), `Approval` (author→app approvals)
  - `PostSubscription` (user→targetAuthor subscriptions for post notifications)

## API server

See `api/README.md` for full details. Minimal steps:

```sh
cd api
bun install
# Optionally start Postgres and Redis
docker compose up -d
# Apply DB migrations
bunx prisma migrate deploy
# Run the server
bun run dev
# (opt) workers & listener in separate terminals
bun run workers
BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/KEY" bun run listener
```

Environment variables (selection; see `api/README.md`):

- `DATABASE_URL`, `REDIS_URL`, `REDIS_QUEUE_URL`, `JWT_SECRET`
- `APNS_KEY` or `APNS_KEY_PATH`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`
- `NODE_ENV`, `BASE_RPC_URL`

## Configuration Reference

### Build Process

The app uses a build-time configuration system:

- **`Info.plist.template`** - Source template (committed to git)
- **`Info.plist`** - Generated at build time (ignored by git)
- **`.env`** - Local environment variables (ignored by git)
- **`ci_scripts/ci_pre_xcodebuild.sh`** - Build script that generates Info.plist

### Configuration Priority

`AppConfiguration.swift` reads values in this order:

1. **Generated Info.plist** (from build process)
2. **Process environment variables** (for previews/tests)
3. **Default fallback values**

### Xcode Build Phase

The build process automatically runs before compilation:

1. Copies `Info.plist.template` to `Info.plist`
2. Reads environment variables from `.env` file (if present)
3. Applies environment variables to the generated Info.plist
4. Xcode uses the generated Info.plist for the build

### Service Integration

- `ecp_clientApp.swift` wires `AuthService`, `NotificationService`, `DeepLinkService`, and promotes deep links from notifications
- Foreground notifications are shown as banner/list/sound via `UNUserNotificationCenterDelegate`

## Contributing / Development

### iOS Development

- **SwiftUI**: `@StateObject` service pattern, modular views, skeletons, and haptics
- **Build Process**: Environment variables are applied at build time via `ci_scripts/ci_pre_xcodebuild.sh`
- **Configuration**: Never commit generated `Info.plist` - it's ignored by git and regenerated on each build
- **Local Setup**: Create `.env` file from `.env.example` for personal configuration

### API Development

- **Framework**: Hono routes under `api/src/routes`, Prisma client at `api/src/generated/prisma`, workers under `api/src/workers`
- **Environment**: Configure via `.env` file in the `api/` directory

### Development Workflow

```bash
# 1. Clone and setup
git clone <repository-url>
cd ecp-client

# 2. Configure environment
cp .env.example .env
# Edit .env with your values

# 3. Build (Info.plist is generated automatically)
open ecp-client.xcodeproj
# or
./build-personal.sh
```

### Important Notes

- **Never commit `Info.plist`** - It's generated at build time and ignored by git
- **Always commit `Info.plist.template`** - This is the source of truth for the Info.plist structure
- **Environment isolation** - Each developer can have their own `.env` file without affecting others

## Documentation

- [SUPPORT.md](SUPPORT.md) - Support information
- [PRIVACY.md](PRIVACY.md) - Privacy policy

## License

MIT
