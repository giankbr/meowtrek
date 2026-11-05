import express from "express";
import { cfg } from "./config.js";
import { appstore } from "./routes/appstore.js";
import { coach } from "./routes/coach.js";
import { garmin } from "./routes/garmin.js";
import { groups } from "./routes/groups.js";
import { push } from "./routes/push.js";
import { telemetry } from "./routes/telemetry.js";

const app = express();
app.use(express.json({ limit: "3mb" }));

app.get("/v1/health", (_req, res) => res.json({ ok: true }));
app.use("/v1/appstore", appstore);
app.use("/v1/coach", coach);
app.use("/v1/garmin", garmin);
app.use("/v1/groups", groups);
app.use("/v1/push", push);
app.use("/v1/telemetry", telemetry);

app.use((_req, res) => res.status(404).json({ error: "not_found" }));
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: "internal" });
});

app.listen(cfg.port, () => console.log(`meowtrek-api on http://localhost:${cfg.port}`));
