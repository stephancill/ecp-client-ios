import { Hono } from "hono";
import { getHonoRoute } from "./lib/bullboard";
import notificationsApp from "./routes/notifications";
import siweApp from "./routes/siwe";

const app = new Hono();

app.route("/bullboard", getHonoRoute("/bullboard"));
app.route("/api/auth", siweApp);
app.route("/api/notifications", notificationsApp);

app.get("/", (c) => {
  return c.text("Hello Hono!");
});

export default app;
