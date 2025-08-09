import { Hono } from "hono";
import { jwt } from "hono/jwt";
import { syncApprovalsForApp } from "../lib/approvals";

const JWT_SECRET = process.env.JWT_SECRET!;

const app = new Hono();

// POST /api/approvals/sync
app.post(
  "/sync",
  jwt({
    secret: JWT_SECRET,
    cookie: "auth",
    headerName: "Authorization",
  }),
  async (c) => {
    try {
      const { sub: userId } = c.get("jwtPayload") as { sub: string };

      // Optional chainId in body; default to Base mainnet 8453
      let chainId = 8453;
      try {
        const body = await c.req.json();
        if (body && typeof body.chainId === "number") {
          chainId = body.chainId;
        }
      } catch (_e) {
        // ignore body parse errors; default chainId will be used
      }

      const result = await syncApprovalsForApp({ appAddress: userId, chainId });

      return c.json({ success: true, ...result });
    } catch (error) {
      console.error("Error syncing approvals:", error);
      return c.json({ error: "Failed to sync approvals" }, 500);
    }
  }
);

export default app;
