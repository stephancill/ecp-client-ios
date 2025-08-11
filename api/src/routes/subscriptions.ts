import { Hono } from "hono";
import { jwt } from "hono/jwt";
import { prisma } from "../lib/prisma";
import { isAddress } from "viem";
import { JWT_SECRET } from "../lib/constants";

const app = new Hono();

// GET /api/subscriptions/posts?author=0x...
app.get(
  "/posts",
  jwt({ secret: JWT_SECRET, cookie: "auth", headerName: "Authorization" }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };
    const url = new URL(c.req.url);
    const author = url.searchParams.get("author");

    try {
      if (author) {
        if (!isAddress(author)) {
          return c.json({ error: "Invalid author address" }, 400);
        }
        const sub = await prisma.postSubscription.findFirst({
          where: { userId, targetAuthor: author.toLowerCase() },
          select: {
            id: true,
            userId: true,
            targetAuthor: true,
            createdAt: true,
            updatedAt: true,
          },
        });
        return c.json({
          success: true,
          subscribed: !!sub,
          subscription: sub || null,
        });
      }

      const subs = await prisma.postSubscription.findMany({
        where: { userId },
        select: {
          id: true,
          targetAuthor: true,
          createdAt: true,
          updatedAt: true,
        },
        orderBy: { createdAt: "desc" },
      });
      return c.json({ success: true, subscriptions: subs });
    } catch (e) {
      console.error("Failed to get subscriptions", e);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// POST /api/subscriptions/posts { author: "0x..." }
app.post(
  "/posts",
  jwt({ secret: JWT_SECRET, cookie: "auth", headerName: "Authorization" }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };
    try {
      const body = await c.req.json();
      const author: unknown = body?.author;
      if (typeof author !== "string" || !isAddress(author)) {
        return c.json(
          { error: "author is required and must be a valid address" },
          400
        );
      }

      // Ensure user exists
      await prisma.user.upsert({
        where: { id: userId },
        update: { updatedAt: new Date() },
        create: { id: userId },
      });

      const sub = await prisma.postSubscription.upsert({
        where: {
          userId_targetAuthor: { userId, targetAuthor: author.toLowerCase() },
        },
        update: { updatedAt: new Date() },
        create: { userId, targetAuthor: author.toLowerCase() },
      });

      return c.json({ success: true, id: sub.id });
    } catch (e) {
      console.error("Failed to create subscription", e);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

// DELETE /api/subscriptions/posts/:author
app.delete(
  "/posts/:author",
  jwt({ secret: JWT_SECRET, cookie: "auth", headerName: "Authorization" }),
  async (c) => {
    const { sub: userId } = c.get("jwtPayload") as { sub: string };
    const { author } = c.req.param();
    try {
      if (!isAddress(author)) {
        return c.json({ error: "Invalid author address" }, 400);
      }
      const deleted = await prisma.postSubscription.deleteMany({
        where: { userId, targetAuthor: author.toLowerCase() },
      });
      if (deleted.count === 0) {
        return c.json({ error: "Subscription not found" }, 404);
      }
      return c.json({ success: true });
    } catch (e) {
      console.error("Failed to delete subscription", e);
      return c.json({ error: "Internal server error" }, 500);
    }
  }
);

export default app;
