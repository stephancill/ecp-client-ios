import { Hono } from "hono";
import { jwt } from "hono/jwt";
import { prisma } from "../lib/prisma";
import { syncApprovalsForApp } from "../lib/approvals";
import { sendNotficationToUser } from "../lib/notifications";
import { fetchBatchCachedUserData } from "../lib/ecp";
import { isAddress } from "viem";
import { JWT_SECRET } from "../lib/constants";

const app = new Hono();

// GET /api/notifications
app.get(
  "/",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };

    try {
      const notifications = await prisma.notificationDetails.findMany({
        where: { userId },
        select: {
          id: true,
          deviceToken: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      return c.json({
        success: true,
        notifications,
      });
    } catch (error) {
      console.error("Error retrieving notification details:", error);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// GET /api/notifications/events
app.get(
  "/events",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };

    try {
      const url = new URL(c.req.url);
      const limitParam = url.searchParams.get("limit");
      const cursor = url.searchParams.get("cursor");
      const take = Math.min(Math.max(parseInt(limitParam || "50"), 1), 200);

      const found = await prisma.notificationEvent.findMany({
        where: { userId },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: take + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        select: {
          id: true,
          type: true,
          originAddress: true,
          chainId: true,
          subjectCommentId: true,
          targetCommentId: true,
          parentCommentId: true,
          reactionType: true,
          groupKey: true,
          title: true,
          body: true,
          badge: true,
          sound: true,
          data: true,
          createdAt: true,
        },
      });

      // Restrict grouping to the current response window; paginate using raw items
      const pageWindow = found.slice(0, take);
      const hasMoreRaw = found.length > take;

      // Enrich with cached user profiles for actor and parent if present
      const authorAddresses = new Set<string>();
      for (const ev of pageWindow) {
        const data: any = ev.data || {};
        const actor =
          (typeof ev.originAddress === "string" && ev.originAddress) ||
          (typeof data.actorAddress === "string" && data.actorAddress) ||
          undefined;
        const parent =
          (typeof data.parentAddress === "string" && data.parentAddress) ||
          undefined;
        if (actor && isAddress(actor)) authorAddresses.add(actor.toLowerCase());
        if (parent && isAddress(parent))
          authorAddresses.add(parent.toLowerCase());
      }
      // Use lowercase addresses to align with cache keys
      const addressList = Array.from(authorAddresses).map((a) =>
        a.toLowerCase()
      ) as `0x${string}`[];
      const profilesMap = addressList.length
        ? await fetchBatchCachedUserData({ authors: addressList })
        : {};

      const toJsonSafe = (obj: any) =>
        JSON.parse(
          JSON.stringify(obj, (_k, v) =>
            typeof v === "bigint" ? v.toString() : v
          )
        );

      type EnrichedEvent = ReturnType<typeof toJsonSafe> & {
        id: string;
        type: string | null;
        originAddress: string | null;
        reactionType: string | null;
        groupKey: string | null;
        title: string;
        body: string;
        data?: any;
        createdAt: any;
        actorProfile?: any;
        parentProfile?: any;
        otherActorProfiles?: any[];
        targetCommentId?: string | null;
        parentCommentId?: string | null;
      };

      const enriched: EnrichedEvent[] = pageWindow.map((ev) => {
        const data: any = ev.data || {};
        const actorAddress =
          (typeof ev.originAddress === "string" && isAddress(ev.originAddress)
            ? ev.originAddress.toLowerCase()
            : undefined) ??
          (typeof data.actorAddress === "string" && isAddress(data.actorAddress)
            ? data.actorAddress.toLowerCase()
            : undefined);
        const parentAddress =
          typeof data.parentAddress === "string" &&
          isAddress(data.parentAddress)
            ? data.parentAddress.toLowerCase()
            : undefined;
        const actorKey = actorAddress?.toLowerCase() as
          | `0x${string}`
          | undefined;
        const parentKey = parentAddress?.toLowerCase() as
          | `0x${string}`
          | undefined;
        return {
          ...(ev as any),
          actorProfile: actorKey
            ? toJsonSafe(profilesMap[actorKey])
            : undefined,
          parentProfile: parentKey
            ? toJsonSafe(profilesMap[parentKey])
            : undefined,
        } as any;
      });

      // Group reaction events by groupKey and modify the TITLE to include aggregation
      // Body should become the post content (parent/target comment body)
      const isReaction = (e: EnrichedEvent) =>
        (e.type || "") === "reaction" && !!e.groupKey;

      const displayNameFromProfile = (
        profile: any,
        fallbackAddress?: string | null
      ): string => {
        const ensName = profile?.ens?.name;
        const fcUsername = profile?.farcaster?.username;
        if (typeof ensName === "string" && ensName.length > 0) return ensName;
        if (typeof fcUsername === "string" && fcUsername.length > 0)
          return fcUsername;
        const addr = (fallbackAddress || "").toString();
        return addr && addr.startsWith("0x") && addr.length > 10
          ? `${addr.slice(0, 6)}...${addr.slice(-4)}`
          : addr || "Someone";
      };

      // Build groups while preserving the position of the first occurrence
      const groupMap = new Map<
        string,
        {
          indices: number[];
          events: EnrichedEvent[];
        }
      >();
      const passthrough: { index: number; event: EnrichedEvent }[] = [];

      enriched.forEach((ev, idx) => {
        if (isReaction(ev)) {
          const key = ev.groupKey as string;
          const g = groupMap.get(key) || { indices: [], events: [] };
          g.indices.push(idx);
          g.events.push(ev);
          groupMap.set(key, g);
        } else {
          passthrough.push({ index: idx, event: ev });
        }
      });

      // Create aggregated events for each group at the position of the first occurrence
      const aggregated: { index: number; event: any }[] = [];
      groupMap.forEach((g, key) => {
        const sorted = g.events;
        const first = sorted[0];

        // Unique actor addresses for this group (up to 6 for avatars)
        const uniqueActorAddresses: string[] = [];
        for (const e of sorted) {
          const addr =
            (e.originAddress &&
              isAddress(e.originAddress) &&
              e.originAddress.toLowerCase()) ||
            (e.data?.actorAddress &&
              isAddress(e.data.actorAddress) &&
              e.data.actorAddress.toLowerCase()) ||
            undefined;
          if (addr && !uniqueActorAddresses.includes(addr)) {
            uniqueActorAddresses.push(addr);
          }
        }

        const firstActorAddress =
          uniqueActorAddresses[0] || first.originAddress || null;
        const firstActorProfile = firstActorAddress
          ? (profilesMap[firstActorAddress as `0x${string}`] as any)
          : undefined;
        const actorDisplay = displayNameFromProfile(
          firstActorProfile,
          firstActorAddress
        );

        const othersCount = Math.max(0, uniqueActorAddresses.length - 1);
        const rt = (first.reactionType || "reaction").toLowerCase();
        const verb = rt === "like" ? "liked" : "reacted to";
        const title =
          othersCount > 0
            ? `${actorDisplay} and ${othersCount} other${
                othersCount > 1 ? "s" : ""
              } ${verb} your post`
            : `${actorDisplay} ${verb} your post`;

        const body = first.body;
        const id = first.id;
        const createdAt = first.createdAt;

        // Collect profiles for the first 10 other actors
        const otherAddresses = uniqueActorAddresses.slice(1, 11);
        const otherProfiles = otherAddresses
          .map((addr) => profilesMap[addr as `0x${string}`])
          .filter(Boolean)
          .map((p) => toJsonSafe(p));

        const aggregatedEvent = {
          ...first,
          id,
          createdAt,
          title,
          body,
          actorProfile: firstActorProfile
            ? toJsonSafe(firstActorProfile)
            : first.actorProfile,
          otherActorProfiles: otherProfiles,
          data: {
            ...(first.data || {}),
            actorAddresses: uniqueActorAddresses.slice(0, 6),
            actorCount: uniqueActorAddresses.length,
          },
        } as any;

        aggregated.push({
          index: Math.min(...g.indices),
          event: aggregatedEvent,
        });
      });

      // Combine passthrough and aggregated, then sort by original index to maintain order
      const combined = [...passthrough, ...aggregated]
        .sort((a, b) => a.index - b.index)
        .map((x) => x.event);

      // Pagination is based on raw window, not grouped size
      const events = combined;
      const nextCursor = hasMoreRaw
        ? pageWindow[pageWindow.length - 1]?.id ?? null
        : null;

      return c.json({ success: true, events, nextCursor });
    } catch (error) {
      console.error("Error retrieving notification events:", error);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// GET /api/notifications/status
app.get(
  "/status",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };

    try {
      const notifications = await prisma.notificationDetails.findMany({
        where: { userId },
        select: { deviceToken: true, createdAt: true, updatedAt: true },
      });

      const tokens = notifications.map((n) => n.deviceToken);
      return c.json({
        success: true,
        registered: tokens.length > 0,
        count: tokens.length,
        tokens,
        details: notifications,
      });
    } catch (error) {
      console.error("Error retrieving notification status:", error);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// POST /api/notifications
app.post(
  "/",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };

    try {
      const body = await c.req.json();
      const { deviceToken } = body;

      if (!deviceToken || typeof deviceToken !== "string") {
        return c.json(
          { error: "deviceToken is required and must be a string" },
          400
        );
      }

      const deviceTokenRegex = /^[0-9a-fA-F]{64}$/;
      if (!deviceTokenRegex.test(deviceToken)) {
        return c.json({ error: "Invalid device token format" }, 400);
      }

      await prisma.user.upsert({
        where: { id: userId },
        update: { updatedAt: new Date() },
        create: { id: userId },
      });

      const notificationDetails = await prisma.notificationDetails.upsert({
        where: {
          userId_deviceToken: {
            userId,
            deviceToken,
          },
        },
        update: {
          updatedAt: new Date(),
        },
        create: {
          userId,
          deviceToken,
        },
      });

      try {
        await syncApprovalsForApp({ appAddress: userId, chainId: 8453 });
      } catch (e) {
        console.error(
          "Failed to sync approvals during notifications registration:",
          e
        );
      }

      return c.json({
        success: true,
        message: "Notification details stored successfully",
        id: notificationDetails.id,
      });
    } catch (error) {
      console.error("Error storing notification details:", error);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// DELETE /api/notifications/:deviceToken
app.delete(
  "/:deviceToken",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };
    const { deviceToken } = c.req.param();

    try {
      const deviceTokenRegex = /^[0-9a-fA-F]{64}$/;
      if (!deviceTokenRegex.test(deviceToken)) {
        return c.json({ error: "Invalid device token format" }, 400);
      }

      const deleted = await prisma.notificationDetails.deleteMany({
        where: {
          userId,
          deviceToken,
        },
      });

      if (deleted.count === 0) {
        return c.json({ error: "Device token not found for this user" }, 404);
      }

      return c.json({
        success: true,
        message: "Device token removed successfully",
      });
    } catch (error) {
      console.error("Error removing device token:", error);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// POST /api/notifications/test
app.post(
  "/test",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };

    try {
      const testNotification = {
        title: "Test Notification",
        body: "This is a test notification from ECP Client!",
        data: { test: true, timestamp: Date.now() },
      };

      await sendNotficationToUser({ userId, notification: testNotification });

      return c.json({
        success: true,
        message: "Test notification sent successfully",
      });
    } catch (error) {
      console.error("Error sending test notification:", error);
      return c.json({ error: "Failed to send test notification" }, 500);
    }
  }
);

export default app;
