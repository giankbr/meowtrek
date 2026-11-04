import { Hono } from "hono";
import { z } from "zod";
import { today, type AppEnv, type Env } from "./env";

// Anonymous by design: events are stored only as per-day counters and crash reports carry no user or device id.
export const telemetry = new Hono<AppEnv>();

const EventName = z.string().regex(/^[a-z][a-z0-9_]{1,39}$/);
const EventsBody = z.object({
  appVersion: z.string().max(20),
  events: z.array(z.object({ name: EventName, count: z.number().int().min(1).max(500).default(1) })).min(1).max(50),
});
const DiagnosticsBody = z.object({
  appVersion: z.string().max(20),
  osVersion: z.string().max(40),
  model: z.string().max(40),
  payload: z.string().min(2).max(250_000),
});

const DIAG_TTL = 30 * 24 * 3600;
const EVENT_TTL = 400 * 24 * 3600;

async function bump(env: Env, key: string, by: number) {
  const n = Number((await env.KV.get(key)) ?? 0) + by;
  await env.KV.put(key, String(n), { expirationTtl: EVENT_TTL });
}

telemetry.post("/events", async (c) => {
  const parsed = EventsBody.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);
  const date = today();
  const totals = new Map<string, number>();
  for (const e of parsed.data.events) totals.set(e.name, (totals.get(e.name) ?? 0) + e.count);
  await Promise.all([...totals].map(([name, n]) => bump(c.env, `tm:ev:${date}:${name}`, n)));
  await bump(c.env, `tm:ver:${date}:${parsed.data.appVersion.replace(/[^0-9A-Za-z.]/g, "")}`, 1);
  return c.json({ ok: true });
});

telemetry.post("/diagnostics", async (c) => {
  const parsed = DiagnosticsBody.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);
  const { payload, ...meta } = parsed.data;
  let kinds: string[] = [];
  try {
    const p = JSON.parse(payload);
    kinds = ["crashDiagnostics", "hangDiagnostics", "cpuExceptionDiagnostics", "diskWriteExceptionDiagnostics"].filter(
      (k) => Array.isArray(p[k]) && p[k].length > 0,
    );
  } catch {
    return c.json({ error: "invalid_request" }, 400);
  }
  const key = `tm:diag:${today()}:${crypto.randomUUID()}`;
  await c.env.KV.put(key, payload, { expirationTtl: DIAG_TTL, metadata: { ...meta, kinds } });
  return c.json({ ok: true });
});

telemetry.get("/summary", async (c) => {
  const token = c.env.ADMIN_TOKEN;
  if (!token || c.req.header("Authorization") !== `Bearer ${token}`) return c.json({ error: "forbidden" }, 403);
  const days = Math.min(90, Math.max(1, Number(c.req.query("days") ?? 7) || 7));
  const out: { date: string; events: Record<string, number>; versions: Record<string, number> }[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const date = today(new Date(Date.now() - i * 86_400_000));
    const events: Record<string, number> = {};
    const versions: Record<string, number> = {};
    for (const { name } of (await c.env.KV.list({ prefix: `tm:ev:${date}:` })).keys)
      events[name.slice(`tm:ev:${date}:`.length)] = Number((await c.env.KV.get(name)) ?? 0);
    for (const { name } of (await c.env.KV.list({ prefix: `tm:ver:${date}:` })).keys)
      versions[name.slice(`tm:ver:${date}:`.length)] = Number((await c.env.KV.get(name)) ?? 0);
    out.push({ date, events, versions });
  }
  const diagnostics = (await c.env.KV.list({ prefix: "tm:diag:" })).keys
    .map((k) => ({ key: k.name, ...(k.metadata as object) }))
    .slice(-100);
  return c.json({ days: out, diagnostics });
});
