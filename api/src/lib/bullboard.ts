import { createBullBoard } from "@bull-board/api";
import { BullMQAdapter } from "@bull-board/api/bullMQAdapter.js";
import { HonoAdapter } from "@bull-board/hono";
import { commentsQueue, notificationsQueue } from "./queue";
import { serveStatic } from "hono/bun";

// Add basic auth middleware
// const basicAuth = (
//   req: express.Request,
//   res: express.Response,
//   next: express.NextFunction
// ) => {
//   const auth = req.headers.authorization;
//   const envUsername = process.env.BULL_BOARD_USERNAME;
//   const envPassword = process.env.BULL_BOARD_PASSWORD;

//   if (!envUsername || !envPassword) {
//     throw new Error("BULL_BOARD_USERNAME and BULL_BOARD_PASSWORD must be set");
//   }

//   if (!auth || auth.indexOf("Basic ") === -1) {
//     res.setHeader("WWW-Authenticate", 'Basic realm="Bull Board"');
//     res.status(401).send("Authentication required");
//     return;
//   }

//   const credentials = Buffer.from(auth.split(" ")[1], "base64")
//     .toString()
//     .split(":");
//   const username = credentials[0];
//   const password = credentials[1];

//   if (username === envUsername && password === envPassword) {
//     next();
//   } else {
//     res.setHeader("WWW-Authenticate", 'Basic realm="Bull Board"');
//     res.status(401).send("Invalid credentials");
//   }
// };

// export function initExpressApp() {
//   const port = process.env.PORT || 3005;
//   const app = express();
//   const serverAdapter = new ExpressAdapter();

//   // Add basic auth middleware before the bull board routes
//   if (process.env.BULL_BOARD_PASSWORD && process.env.BULL_BOARD_USERNAME) {
//     app.use("/", basicAuth);
//   }

//   serverAdapter.setBasePath("/");
//   app.use("/", serverAdapter.getRouter());

//   createBullBoard({
//     queues: [
//       new BullMQAdapter(notificationsBulkQueue),
//       new BullMQAdapter(stylizeImageQueue),
//     ],
//     serverAdapter,
//   });

//   app.listen(port, () => {
//     console.log("Server started on http://localhost:" + port);
//   });
// }

export function getHonoRoute(basePath: string) {
  const serverAdapter = new HonoAdapter(serveStatic);

  createBullBoard({
    queues: [
      new BullMQAdapter(notificationsQueue),
      new BullMQAdapter(commentsQueue),
    ],
    serverAdapter,
  });

  serverAdapter.setBasePath(basePath);
  return serverAdapter.registerPlugin();
}
