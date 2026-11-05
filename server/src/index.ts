import { Hono } from "hono";
import { appstore } from "./appstore";
import { makeAnthropic } from "./claude";
import { coach } from "./coach";
import type { AppEnv, Deps } from "./env";
import { garmin } from "./garmin";
import { groups } from "./groups";
import { telemetry } from "./telemetry";

export function createApp(deps: Partial<Deps> = {}) {
  const resolved: Deps = { anthropic: makeAnthropic, fetch: (...a) => fetch(...a), ...deps };
  const app = new Hono<AppEnv>();
  app.use("*", async (c, next) => {
    c.set("deps", resolved);
    await next();
  });
  app.get("/v1/health", (c) => c.json({ ok: true }));
  app.route("/v1/appstore", appstore);
  app.route("/v1/coach", coach);
  app.route("/v1/garmin", garmin);
  app.route("/v1/groups", groups);
  app.route("/v1/telemetry", telemetry);
  app.notFound((c) => c.json({ error: "not_found" }, 404));
  app.onError((err, c) => {
    console.error(err);
    return c.json({ error: "internal" }, 500);
  });
  return app;
}

export default createApp();
