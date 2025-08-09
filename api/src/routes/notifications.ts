import { Hono } from "hono";
import { jwt } from "hono/jwt";
import { prisma } from "../lib/prisma";
import { syncApprovalsForApp } from "../lib/approvals";
import { sendNotficationToUser } from "../lib/notifications";

const JWT_SECRET = process.env.JWT_SECRET || "your-super-secret-jwt-key";

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
