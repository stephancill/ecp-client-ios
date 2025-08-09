# Town API

A Bun + Hono backend for ECP (Ethereum Comments Protocol) integrations. It provides:

- SIWE (Sign-In with Ethereum) auth issuing a JWT (cookie-based)
- Device registration and APNs push notifications
- On-chain comment listener and background workers using BullMQ
- Bull Board UI for monitoring queues

Visit `http://localhost:3000` to verify the server is running.

## Quick start

```sh
bun install

# Start Postgres and Redis (optional but recommended for local dev)
docker compose up -d

# Ensure DATABASE_URL is set, then apply DB migrations (if needed)
# If you already have the generated client and DB is empty, this will create tables
bunx prisma migrate deploy

# Start API server (port 3000 by default)
bun run dev

# In separate terminals, you can run:
# Background workers (BullMQ)
bun run workers

# On-chain listener (requires BASE_RPC_URL)
BASE_RPC_URL="https://base-mainnet.g.alchemy.com/v2/KEY" bun run listener
```

## Environment variables

- DATABASE_URL: Postgres connection string (e.g. `postgres://postgres:password@localhost:5432/postgres`)
- REDIS_URL: Redis URL for caching (default `redis://localhost:6379`)
- REDIS_QUEUE_URL: Redis URL for BullMQ queues (defaults to REDIS_URL)
- JWT_SECRET: Secret used to sign JWTs for auth
- NODE_ENV: `production` or `development` (affects APNs environment)
- BASE_RPC_URL: RPC endpoint for Base mainnet, used by the on-chain listener

APNs (push notifications):

- APNS_KEY or APNS_KEY_PATH: Provide the APNs Auth Key PEM contents directly (APNS_KEY) or path to the PEM file (APNS_KEY_PATH)
- APNS_KEY_ID: Key ID from Apple Developer account
- APNS_TEAM_ID: Team ID from Apple Developer account
- APNS_BUNDLE_ID: iOS app bundle identifier (APNs topic)

Notes:

- At least one of `APNS_KEY` or `APNS_KEY_PATH` must be set, along with `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_BUNDLE_ID`.
- `NODE_ENV=production` will use APNs production; otherwise sandbox.

## Features

- Hono HTTP server with cookie-based JWT auth
- SIWE flow with Redis-backed nonce storage
- Device token registration and test notifications
- Approval sync from `https://api.ethcomments.xyz` to local Postgres
- BullMQ queues for `comments` and `notifications`
- Workers that:
  - react to on-chain comments (notify parents and mentions)
  - fan out push notifications to approved app accounts
- Bull Board UI at `/bullboard`

## Services

- API server: `bun run dev` (Hono default port 3000)
- Workers: `bun run workers`
- Listener: `bun run listener` (requires `BASE_RPC_URL`)
- Bull Board: `http://localhost:3000/bullboard` (consider protecting behind auth/reverse proxy in production)

## API reference

Base URL: `http://localhost:3000`

### Auth (SIWE)

Base path: `/api/auth`

- POST `/nonce`

  - Body: `{ "address": "0x..." }`
  - Response: `{ nonce: string, message: string }`

- POST `/verify`

  - Body: `{ "message": string, "signature": string }`
  - Sets `auth` HTTP-only cookie with JWT. Also returns `{ success: true, approved: boolean, token: string }`.

- POST `/logout`

  - Clears the `auth` cookie. Requires auth.

- GET `/me`
  - Returns the JWT payload. Requires auth.

Notes:

- Auth uses a JWT cookie named `auth` signed with `JWT_SECRET`.
- Nonces are stored in Redis for 10 minutes; they are single-use and deleted on successful verification.

### Notifications

Base path: `/api/notifications` (all endpoints require auth via `auth` cookie or `Authorization: Bearer <token>` header)

- GET `/`

  - Returns notification device registrations for the authenticated user.
  - Response: `{ success: true, notifications: Array<{ id, deviceToken, createdAt, updatedAt }> }`

- GET `/status`

  - Returns summary: `{ success: true, registered: boolean, count: number, tokens: string[], details: ... }`

- POST `/`

  - Registers a device token for push notifications.
  - Body: `{ "deviceToken": string }` (64-hex string)
  - Response: `{ success: true, message: string, id: string }`
  - Side effects: Triggers approval sync for the app account.

- DELETE `/:deviceToken`

  - Removes a device token for the authenticated user.
  - Response: `{ success: true, message: string }`

- POST `/test`
  - Sends a test APNs notification to all of the authenticated user’s devices.
  - Response: `{ success: true, message: string }`

### Misc

- GET `/`

  - Health check. Returns `Hello Hono!` text.

- GET `/bullboard`
  - Bull Board UI for queues. No built-in auth — protect behind network/firewall or reverse proxy in production.

## Background processing

Queues (`src/lib/constants.ts`):

- `notifications` — push notification fanout
- `comments` — on-chain comment processing

Workers (`bun run workers`):

- `notifications` (`src/workers/notifications.ts`): For a given author address, find approved app accounts with registered devices and send APNs notifications in bulk.
- `comments` (`src/workers/comments.ts`): Fetches comment data, notifies parent author on reply/reaction, and any mentioned addresses.

On-chain listener (`bun run listener`):

- Watches the ECP `CommentManager` on Base and enqueues `processComment` jobs into the `comments` queue.

## Data model (Prisma)

- `User`: primary key is the app address (lowercased/normalized). Holds relations to `notifications` and `approvals`.
- `NotificationDetails`: device token registrations per user; unique on `(userId, deviceToken)`.
- `Approval`: approvals of authors for app accounts; soft-deletable via `deletedAt`. Unique on `(author, app, chainId)`.

## Types

```ts
// src/types/notifications.ts
export interface NotificationData {
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  data?: Record<string, any>;
}

// src/types/jobs.ts
export type NotificationJobData = {
  author: string; // author address
  notification: NotificationData;
};

export type CommentJobData = {
  commentId: string;
  content?: string;
  parentId?: string;
  commentType?: number; // 1 = reaction
  chainId: number;
};
```

## Development notes

- Device tokens must be 64 hex characters (APNs token format). Invalid tokens are rejected and stale/invalid tokens may be cleaned up automatically after APNs errors.
- Approval sync fetches from `https://api.ethcomments.xyz` and upserts to local Postgres; verification endpoints also sync to return up-to-date status.
- The Prisma client is generated into `src/generated/prisma`. If you change the schema, run `bunx prisma generate` and apply migrations.

## License

MIT
