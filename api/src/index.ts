import { Hono } from "hono";
import { basicAuth } from "hono/basic-auth";
import { getHonoRoute } from "./lib/bullboard";
import notificationsApp from "./routes/notifications";
import siweApp from "./routes/siwe";

const app = new Hono();

// Protect Bull Board with Basic Auth when credentials are provided via env
const bullboardUsername = Bun.env.BULL_BOARD_USERNAME;
const bullboardPassword = Bun.env.BULL_BOARD_PASSWORD;

if (bullboardUsername && bullboardPassword) {
  app.use(
    "/bullboard/*",
    basicAuth({
      username: bullboardUsername,
      password: bullboardPassword,
      realm: "Bull Board",
    })
  );
} else {
  console.warn(
    "[bullboard] BULL_BOARD_USERNAME or BULL_BOARD_PASSWORD not set — route will be unprotected"
  );
}

app.route("/bullboard", getHonoRoute("/bullboard"));
app.route("/api/auth", siweApp);
app.route("/api/notifications", notificationsApp);

app.get("/", (c) => {
  return c.text("Hello Hono!");
});

export default app;
