import Anthropic from "@anthropic-ai/sdk";
import { type Request, type Response, Router } from "express";
import type { z } from "zod";
import * as ai from "../claude.js";
import { makeAnthropic } from "../claude.js";
import { cfg, type Plan } from "../config.js";
import { consume, type LimitKind, remaining } from "../lib/limits.js";
import { resolvePlan } from "../lib/apple.js";
import { ChatBody, Device, InsightBody, MealBody, QuestsBody } from "../schemas.js";

export const coach = Router();

coach.use(async (req, res, next) => {
  const device = req.header("X-Meowtrek-Device");
  if (!Device.safeParse(device).success) return res.status(401).json({ error: "device_required" });
  if (!cfg.anthropicKey) return res.status(503).json({ error: "ai_not_configured" });
  (req as any).device = device;
  const plan = await resolvePlan(req.header("X-Meowtrek-Transaction"), device);
  (req as any).plan = plan;
  res.setHeader("X-Plan", plan);
  next();
});

async function handle<S extends z.ZodType, R>(
  req: Request,
  res: Response,
  kind: LimitKind,
  schema: S,
  run: (client: Anthropic, body: z.infer<S>) => Promise<R>,
) {
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({ error: "invalid_request", issues: parsed.error.issues.map((i) => ({ path: i.path.join("."), message: i.message })) });
  }
  const device = (req as any).device as string;
  const plan = (req as any).plan as Plan;
  if ((await remaining(kind, device, plan)) <= 0) {
    res.setHeader("X-Remaining", "0");
    return res.status(429).json({ error: "limit", remaining: 0 });
  }
  try {
    const result = await run(makeAnthropic(), parsed.data);
    res.setHeader("X-Remaining", String(await consume(kind, device, plan)));
    return res.json(result);
  } catch (err) {
    if (err instanceof ai.AiRefusal) return res.status(502).json({ error: "ai_unavailable" });
    if (err instanceof Anthropic.RateLimitError || (err instanceof Anthropic.APIError && (err.status ?? 0) >= 500))
      return res.status(503).json({ error: "ai_busy" });
    if (err instanceof Anthropic.APIError) {
      console.error("anthropic error", err.status, err.message);
      return res.status(502).json({ error: "ai_unavailable" });
    }
    console.error(err);
    return res.status(500).json({ error: "internal" });
  }
}

coach.post("/chat", (req, res) =>
  handle(req, res, "chat", ChatBody, async (client, { messages, context }) => {
    const recent = messages.slice(-20);
    while (recent[0]?.role === "assistant") recent.shift();
    return { reply: await ai.chat(client, recent, context) };
  }),
);

coach.post("/insight", (req, res) =>
  handle(req, res, "insight", InsightBody, (client, { context, last28Days }) => ai.insight(client, context, last28Days)),
);

coach.post("/quests", (req, res) =>
  handle(req, res, "quests", QuestsBody, (client, { context, localHour }) => ai.quests(client, context, localHour).then((quests) => ({ quests }))),
);

coach.post("/meal", (req, res) =>
  handle(req, res, "meal", MealBody, (client, { context, image, mediaType }) => ai.meal(client, context, image, mediaType)),
);
