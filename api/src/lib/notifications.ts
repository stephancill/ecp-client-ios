import { prisma } from "./prisma";
import * as apn from "apn";
import * as fs from "fs";
import { NotificationData } from "../types/notifications";
import { isAddress } from "viem";

// Enforce conservative limits to avoid APNs 4KB payload cap
const MAX_ALERT_TITLE_CHARS = 80;
const MAX_ALERT_BODY_CHARS = 220;

function truncateString(value: unknown, maxChars: number): string | undefined {
  if (typeof value !== "string") return undefined;
  if (value.length <= maxChars) return value;
  return value.slice(0, Math.max(0, maxChars - 1)).trimEnd() + "\u2026"; // ellipsis
}

const allowedDataKeys = new Set([
  "type",
  "commentId",
  "parentId",
  "chainId",
  "actorAddress",
  "parentAddress",
]);

export function sanitizeNotificationData(
  notification: NotificationData
): NotificationData {
  const sanitized: NotificationData = {
    title:
      truncateString(notification.title, MAX_ALERT_TITLE_CHARS) ||
      String(notification.title ?? ""),
    body:
      truncateString(notification.body, MAX_ALERT_BODY_CHARS) ||
      String(notification.body ?? ""),
  };

  if (typeof notification.badge === "number")
    sanitized.badge = notification.badge;
  if (typeof notification.sound === "string")
    sanitized.sound = notification.sound;

  if (notification.data && typeof notification.data === "object") {
    const data: Record<string, any> = {};
    for (const [key, value] of Object.entries(notification.data)) {
      if (!allowedDataKeys.has(key)) continue; // drop non-essential / large fields
      if (typeof value === "string") {
        // Keep IDs/addresses as-is; they are short. Truncate any arbitrary strings.
        const isHexId = /^0x[0-9a-fA-F]+$/.test(value);
        data[key] = isHexId ? value : truncateString(value, 256) ?? value;
      } else if (
        typeof value === "number" ||
        typeof value === "boolean" ||
        value === null
      ) {
        data[key] = value;
      } else {
        // Drop nested objects/arrays entirely to stay small
      }
    }
    sanitized.data = Object.keys(data).length ? data : undefined;
  }

  return sanitized;
}

const apnsKey: string = process.env.APNS_KEY || "";
const apnsKeyId: string = process.env.APNS_KEY_ID || "";
const apnsTeamId: string = process.env.APNS_TEAM_ID || "";
const apnsBundleId: string | undefined = process.env.APNS_BUNDLE_ID;
const apnsEnvironment: "sandbox" | "production" = (
  process.env.NODE_ENV === "production" ? "production" : "sandbox"
) as "sandbox" | "production";
const apnsKeyPath: string = process.env.APNS_KEY_PATH || "";

let apnsProvider: apn.Provider | undefined;
let apnsInitPromise: Promise<void> | undefined;

function assertApnsEnv() {
  const hasKey = !!apnsKey && apnsKey.trim().length > 0;
  const hasKeyPath = !!apnsKeyPath && apnsKeyPath.trim().length > 0;
  const missing: string[] = [];
  if (!hasKey && !hasKeyPath) missing.push("APNS_KEY or APNS_KEY_PATH");
  if (!apnsKeyId) missing.push("APNS_KEY_ID");
  if (!apnsTeamId) missing.push("APNS_TEAM_ID");
  if (!apnsBundleId) missing.push("APNS_BUNDLE_ID");
  if (missing.length) {
    throw new Error(
      `Missing required APNs configuration: ${missing.join(
        ", "
      )}. Set these environment variables.`
    );
  }
}

function loadApnsKeyPem(): string | null {
  if (apnsKeyPath) {
    try {
      const pem = fs.readFileSync(apnsKeyPath, "utf8");
      return pem;
    } catch (err) {
      throw new Error(
        `Failed to read APNS_KEY_PATH file at ${apnsKeyPath}: ${String(err)}`
      );
    }
  }

  // Priority 2: APNS_KEY with PEM content or base64-encoded PEM
  if (apnsKey) {
    // Heuristics: base64 often starts with "LS0t" (--- in base64)
    const isBase64 =
      /^[A-Za-z0-9+/=\r\n]+$/.test(apnsKey) && apnsKey.includes("LS0t");
    if (isBase64) {
      try {
        const decoded = Buffer.from(apnsKey, "base64").toString("utf8");
        return decoded;
      } catch (e) {
        throw new Error("APNS_KEY looked like base64 but failed to decode");
      }
    }
    return apnsKey;
  }

  return null;
}

function initApnsProviderIfPossible(): Promise<void> | void {
  // Ensure required creds
  assertApnsEnv();
  const pem = loadApnsKeyPem();
  if (!pem) {
    throw new Error("APNs key PEM could not be loaded");
  }

  if (apnsProvider) return;
  if (apnsInitPromise) return apnsInitPromise;

  apnsInitPromise = new Promise((resolve) => {
    try {
      apnsProvider = new apn.Provider({
        token: {
          key: pem,
          keyId: apnsKeyId,
          teamId: apnsTeamId,
        },
        production: apnsEnvironment === "production",
      });
      console.log(
        `APNs provider initialized (env=${apnsEnvironment}, topic=${apnsBundleId})`
      );
    } catch (err) {
      console.error("Failed to initialize APNs provider:", err);
    } finally {
      apnsInitPromise = undefined;
      resolve();
    }
  });

  return apnsInitPromise;
}

/**
 * Exported method: send notification to a specific user (all their devices)
 */
export async function sendNotficationToUser({
  userId,
  notification,
}: {
  userId: string;
  notification: NotificationData;
}): Promise<void> {
  try {
    // Get all device tokens for the user
    const userNotifications = await prisma.notificationDetails.findMany({
      where: {
        userId: isAddress(userId) ? userId.toLowerCase() : userId,
      },
    });

    if (userNotifications.length === 0) {
      console.log(`No device tokens found for user: ${userId}`);
      return;
    }

    const tokens = userNotifications.map((n) => n.deviceToken);
    await sendInBatches(tokens, 5, async (t) => {
      await sendAPNsNotification(t, notification);
    });
    console.log(
      `Sent notification to ${userNotifications.length} devices for user: ${userId}`
    );
  } catch (error) {
    console.error(`Failed to send notification to user ${userId}:`, error);
    throw error;
  }
}

/**
 * Send APNs notification using HTTP/2 API
 */
async function sendAPNsNotification(
  deviceToken: string,
  notification: NotificationData
): Promise<void> {
  try {
    if (!apnsProvider) {
      const maybe = initApnsProviderIfPossible();
      if (maybe) await maybe;
    }

    if (!apnsProvider) {
      console.warn("APNs provider not available. Skipping send.");
      return;
    }

    const sanitized = sanitizeNotificationData(notification);
    const note = new apn.Notification();
    note.topic = apnsBundleId!; // must match bundle id (asserted by assertApnsEnv)
    // iOS 13+ requires correct push type; property may not be typed in @types/apn
    (note as any).pushType = "alert";
    note.priority = 10; // immediate delivery for alert
    note.alert = {
      title: sanitized.title,
      body: sanitized.body,
    } as any;
    note.sound = sanitized.sound || "default";
    if (typeof sanitized.badge === "number") {
      note.badge = sanitized.badge as number;
    }
    if (sanitized.data) {
      note.payload = sanitized.data;
    }

    const result = await apnsProvider.send(note, deviceToken);

    // Handle failures
    if (result.failed && result.failed.length > 0) {
      for (const f of result.failed) {
        const device = (f as any).device || deviceToken;
        const status = (f as any).status;
        const response = (f as any).response;
        const reason = response?.reason || (f as any).error?.message;
        console.warn(
          `APNs send failed for ${String(device).slice(
            0,
            12
          )}... status=${status} reason=${reason}`
        );

        // Cleanup invalid tokens per APNs best-practices
        // 410 (Unregistered) or BadDeviceToken should be removed
        if (status === 410 || reason === "BadDeviceToken") {
          try {
            await prisma.notificationDetails.deleteMany({
              where: { deviceToken },
            });
            console.log(
              `Removed invalid device token ${String(device).slice(0, 12)}...`
            );
          } catch (delErr) {
            console.error("Failed to remove invalid device token:", delErr);
          }
        }
      }
    }

    if (result.sent && result.sent.length > 0) {
      // Optionally log success
      // console.log(`APNs sent: ${result.sent.length} device(s)`);
    }
  } catch (error) {
    console.error(`Failed to send APNs notification to ${deviceToken}:`, error);
    // Don't throw to avoid blocking other sends
  }
}

async function sendInBatches<T>(
  items: T[],
  batchSize: number,
  fn: (item: T) => Promise<any>
) {
  for (let i = 0; i < items.length; i += batchSize) {
    const slice = items.slice(i, i + batchSize);
    await Promise.allSettled(slice.map((item) => fn(item)));
  }
}

// Shutdown provider on process exit
process.on("exit", () => {
  apnsProvider?.shutdown();
});

// Pre-warm APNs provider at module load to avoid first-send latency
initApnsProviderIfPossible();
