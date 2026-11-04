import Anthropic from "@anthropic-ai/sdk";
import { Hono, type Context as HonoCtx } from "hono";
import type { z } from "zod";
import * as ai from "./claude";
import type { AppEnv } from "./env";
import { consume, remaining, type LimitKind } from "./limits";
import { resolvePlan } from "./plus";
import { ChatBody, Device, InsightBody, QuestsBody } from "./schemas";

export const coach = new Hono<AppEnv>();

coach.use("*", async (c, next) => {
  const device = c.req.header("X-Meowtrek-Device");
  if (!Device.safeParse(device).success) return c.json({ error: "device_required" }, 401);
  if (!c.env.ANTHROPIC_API_KEY) return c.json({ error: "ai_not_configured" }, 503);
  c.set("device", device!);
  const plan = await resolvePlan(c.env, c.req.header("X-Meowtrek-Transaction"));
  c.set("plan", plan);
  c.header("X-Plan", plan);
  await next();
});

async function handle<S extends z.ZodType, R>(
  c: HonoCtx<AppEnv>,
  kind: LimitKind,
  schema: S,
  run: (client: Anthropic, body: z.infer<S>) => Promise<R>,
) {
  const parsed = schema.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request", issues: parsed.error.issues.map((i) => ({ path: i.path.join("."), message: i.message })) }, 400);

  const { device, plan } = c.var;
  if ((await remaining(c.env, kind, device, plan)) <= 0) {
    c.header("X-Remaining", "0");
    return c.json({ error: "limit", remaining: 0 }, 429);
  }
  try {
    const result = await run(c.var.deps.anthropic(c.env), parsed.data);
    c.header("X-Remaining", String(await consume(c.env, kind, device, plan)));
    return c.json(result as object);
  } catch (err) {
    if (err instanceof ai.AiRefusal) return c.json({ error: "ai_unavailable" }, 502);
    if (err instanceof Anthropic.RateLimitError || (err instanceof Anthropic.APIError && (err.status ?? 0) >= 500))
      return c.json({ error: "ai_busy" }, 503);
    if (err instanceof Anthropic.APIError) {
      console.error("anthropic error", err.status, err.message);
      return c.json({ error: "ai_unavailable" }, 502);
    }
    throw err;
  }
}

coach.post("/chat", (c) =>
  handle(c, "chat", ChatBody, async (client, { messages, context }) => {
    const recent = messages.slice(-20);
    while (recent[0]?.role === "assistant") recent.shift();
    return { reply: await ai.chat(client, c.env, recent, context) };
  }),
);

coach.post("/insight", (c) =>
  handle(c, "insight", InsightBody, (client, { context, last28Days }) => ai.insight(client, c.env, context, last28Days)),
);

coach.post("/quests", (c) =>
  handle(c, "quests", QuestsBody, (client, { context, localHour }) => ai.quests(client, c.env, context, localHour)),
);
