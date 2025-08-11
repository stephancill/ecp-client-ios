import { Hono } from "hono";
import { deleteCookie, setCookie } from "hono/cookie";
import { jwt, sign } from "hono/jwt";
import { JWT_SECRET } from "../lib/constants";
import { verifyMessage } from "viem";
import { generateSiweNonce, parseSiweMessage } from "viem/siwe";
import { syncApprovalsForApp } from "../lib/approvals";
import { redisCache } from "../lib/redis";

const app = new Hono();

app.post("/nonce", async (c) => {
  try {
    // Extract address from request body
    const { address } = await c.req.json();

    if (!address) {
      return c.json({ error: "Address is required" }, 400);
    }

    // Generate a nonce to be used in the SIWE message.
    // This is used to prevent replay attacks.
    const nonce = generateSiweNonce();

    // Store nonce in Redis for this session (10 minutes).
    await redisCache.setex(`nonce:${nonce}`, 600, "valid");

    // Create SIWE message
    const domain = c.req.header("host") || "localhost:3000";
    const uri = `${c.req.header("x-forwarded-proto") || "http"}://${domain}`;
    const version = "1";
    const chainId = "8453"; // Base mainnet
    const issuedAt = new Date().toISOString();

    const siweMessage = `${domain} wants you to sign in with your Ethereum account:
${address}

Sign in to ECP Client

URI: ${uri}
Version: ${version}
Chain ID: ${chainId}
Nonce: ${nonce}
Issued At: ${issuedAt}`;

    return c.json({ nonce, message: siweMessage });
  } catch (error) {
    console.error("Nonce generation error:", error);
    return c.json({ error: "Failed to generate nonce" }, 500);
  }
});

app.post("/verify", async (c) => {
  try {
    // Extract properties from the request body and SIWE message.
    const { message, signature } = await c.req.json();
    const parsedMessage = parseSiweMessage(message);
    const { address: userAppAddress, nonce } = parsedMessage;

    if (!userAppAddress)
      return c.json({ error: "App address is required" }, 400);

    // If there is no nonce, we cannot verify the signature.
    if (!nonce) return c.json({ error: "Nonce is required" }, 400);

    // Check if the nonce is valid for this session.
    const nonceSession = await redisCache.get(`nonce:${nonce}`);
    if (!nonceSession)
      return c.json({ error: "Invalid or expired nonce" }, 401);

    // Delete the nonce to prevent replay attacks
    await redisCache.del(`nonce:${nonce}`);

    // Verify the signature using viem's verifyMessage
    const valid = await verifyMessage({
      address: userAppAddress!,
      message,
      signature,
    });

    // If the signature is invalid, we cannot authenticate the user.
    if (!valid) return c.json({ error: "Invalid signature" }, 401);

    const maxAge = 60 * 60 * 24 * 7; // 7 days
    const exp = Math.floor(Date.now() / 1000) + maxAge;

    // Sync approvals and determine approval status
    const { approved: isApproved } = await syncApprovalsForApp({
      appAddress: userAppAddress!,
      chainId: 8453,
    });

    // Issue a JWT token for the user in a HTTP-only cookie.
    const token = await sign(
      { exp, sub: userAppAddress.toLowerCase() },
      JWT_SECRET
    );
    setCookie(c, "auth", token, {
      httpOnly: true,
      maxAge,
      path: "/",
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
    });

    return c.json({ success: true, approved: isApproved, token });
  } catch (error) {
    console.error("SIWE verification error:", error);
    return c.json({ error: "Verification failed" }, 500);
  }
});

app.post("/logout", jwt({ cookie: "auth", secret: JWT_SECRET }), async (c) => {
  deleteCookie(c, "auth");
  return c.json({ success: true });
});

app.get("/me", jwt({ cookie: "auth", secret: JWT_SECRET }), async (c) => {
  return c.json(c.get("jwtPayload"));
});

export default app;
