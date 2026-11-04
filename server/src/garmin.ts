// Garmin Connect Developer Program (Health API), OAuth 2.0 PKCE.
// Spec: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE.pdf
// Push/ping payloads ({dailies:[...]}, {deregistrations:[...]}) follow the Health API spec, which is behind the
// developer portal login (https://developerportal.garmin.com/); field names unverified until the account is approved.
import { Hono } from "hono";
import { z } from "zod";
import { today, type AppEnv, type Env } from "./env";
import { Device } from "./schemas";

const AUTHORIZE_URL = "https://connect.garmin.com/oauth2Confirm";
const TOKEN_URL = "https://connectapi.garmin.com/di-oauth2-service/oauth/token";
const API = "https://apis.garmin.com/wellness-api/rest";
const APP_REDIRECT = "meowtrek://garmin";
const STEPS_TTL = 120 * 24 * 3600;

interface GarminUser {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  devices: string[];
}

const k = {
  state: (s: string) => `garmin:state:${s}`,
  device: (d: string) => `garmin:device:${d}`,
  user: (u: string) => `garmin:user:${u}`,
  steps: (u: string, date = "") => `garmin:steps:${u}:${date}`,
};

const b64url = (buf: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

export const configured = (env: Env) => !!(env.GARMIN_CONSUMER_KEY && env.GARMIN_CONSUMER_SECRET);

const TokenRes = z.object({ access_token: z.string(), refresh_token: z.string(), expires_in: z.number() });

async function tokenRequest(env: Env, f: typeof fetch, params: Record<string, string>) {
  const res = await f(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: env.GARMIN_CONSUMER_KEY!, client_secret: env.GARMIN_CONSUMER_SECRET!, ...params }),
  });
  if (!res.ok) throw new Error(`garmin token ${res.status}`);
  const t = TokenRes.parse(await res.json());
  // Refresh 10 min early, per Garmin's recommendation.
  return { accessToken: t.access_token, refreshToken: t.refresh_token, expiresAt: Date.now() + (t.expires_in - 600) * 1000 };
}

async function accessToken(env: Env, f: typeof fetch, userId: string): Promise<string | null> {
  const user = await env.KV.get<GarminUser>(k.user(userId), "json");
  if (!user) return null;
  if (user.expiresAt > Date.now()) return user.accessToken;
  const t = await tokenRequest(env, f, { grant_type: "refresh_token", refresh_token: user.refreshToken });
  await env.KV.put(k.user(userId), JSON.stringify({ ...user, ...t }));
  return t.accessToken;
}

async function unlinkUser(env: Env, userId: string) {
  const user = await env.KV.get<GarminUser>(k.user(userId), "json");
  await Promise.all((user?.devices ?? []).map((d) => env.KV.delete(k.device(d))));
  await env.KV.delete(k.user(userId));
}

const Daily = z.object({
  userId: z.string(),
  calendarDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  steps: z.number().int().min(0).optional(),
  callbackURL: z.string().optional(),
});

async function storeDaily(env: Env, d: z.infer<typeof Daily>) {
  if (!d.calendarDate || d.steps === undefined) return;
  if (!(await env.KV.get(k.user(d.userId)))) return;
  await env.KV.put(k.steps(d.userId, d.calendarDate), "", { metadata: { steps: d.steps }, expirationTtl: STEPS_TTL });
}

async function pullPing(env: Env, f: typeof fetch, userId: string, callbackURL: string) {
  const url = new URL(callbackURL);
  if (url.protocol !== "https:" || url.hostname !== "apis.garmin.com") return;
  const token = await accessToken(env, f, userId);
  if (!token) return;
  const res = await f(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`garmin ping pull ${res.status}`);
  const list = z.array(Daily.partial({ userId: true })).parse(await res.json());
  for (const d of list) await storeDaily(env, { ...d, userId: d.userId ?? userId });
}

export const garmin = new Hono<AppEnv>();

garmin.use("*", async (c, next) => {
  if (!configured(c.env)) return c.json({ error: "garmin_not_configured" }, 503);
  await next();
});

const requireDevice = (h: string | undefined) => (Device.safeParse(h).success ? h! : null);

// App calls this, then opens `url` in ASWebAuthenticationSession (callbackURLScheme "meowtrek").
garmin.get("/authorize", async (c) => {
  const device = requireDevice(c.req.header("X-Meowtrek-Device"));
  if (!device) return c.json({ error: "device_required" }, 401);
  const verifier = b64url(crypto.getRandomValues(new Uint8Array(48)));
  const challenge = b64url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
  const state = b64url(crypto.getRandomValues(new Uint8Array(24)));
  const redirectUri = new URL("/v1/garmin/callback", c.req.url).toString();
  await c.env.KV.put(k.state(state), JSON.stringify({ device, verifier, redirectUri }), { expirationTtl: 600 });
  const url = new URL(AUTHORIZE_URL);
  url.search = new URLSearchParams({
    response_type: "code",
    client_id: c.env.GARMIN_CONSUMER_KEY!,
    code_challenge: challenge,
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    state,
  }).toString();
  return c.json({ url: url.toString() });
});

garmin.get("/callback", async (c) => {
  const back = (status: string) => c.redirect(`${APP_REDIRECT}?status=${status}`, 302);
  const { code, state } = c.req.query();
  if (!state) return back("error");
  const saved = await c.env.KV.get<{ device: string; verifier: string; redirectUri: string }>(k.state(state), "json");
  await c.env.KV.delete(k.state(state));
  if (!saved) return back("expired");
  if (!code) return back("denied");
  const f = c.var.deps.fetch;
  try {
    const t = await tokenRequest(c.env, f, {
      grant_type: "authorization_code",
      code,
      code_verifier: saved.verifier,
      redirect_uri: saved.redirectUri,
    });
    const idRes = await f(`${API}/user/id`, { headers: { Authorization: `Bearer ${t.accessToken}` } });
    if (!idRes.ok) throw new Error(`garmin user id ${idRes.status}`);
    const { userId } = z.object({ userId: z.string().min(1) }).parse(await idRes.json());

    const prevUser = await c.env.KV.get(k.device(saved.device));
    if (prevUser && prevUser !== userId) await unlinkUser(c.env, prevUser);
    const existing = await c.env.KV.get<GarminUser>(k.user(userId), "json");
    const devices = [...new Set([...(existing?.devices ?? []), saved.device])].slice(-5);
    await c.env.KV.put(k.user(userId), JSON.stringify({ ...t, devices } satisfies GarminUser));
    await c.env.KV.put(k.device(saved.device), userId);
    return back("linked");
  } catch (err) {
    console.error("garmin callback", (err as Error).message);
    return back("error");
  }
});

garmin.get("/status", async (c) => {
  const device = requireDevice(c.req.header("X-Meowtrek-Device"));
  if (!device) return c.json({ error: "device_required" }, 401);
  return c.json({ linked: !!(await c.env.KV.get(k.device(device))) });
});

garmin.get("/steps", async (c) => {
  const device = requireDevice(c.req.header("X-Meowtrek-Device"));
  if (!device) return c.json({ error: "device_required" }, 401);
  const days = z.coerce.number().int().min(1).max(90).catch(30).parse(c.req.query("days") ?? 30);
  const userId = await c.env.KV.get(k.device(device));
  if (!userId) return c.json({ error: "garmin_not_linked" }, 404);

  const from = today(new Date(Date.now() - (days - 1) * 86_400_000));
  const out: { date: string; steps: number }[] = [];
  let cursor: string | undefined;
  do {
    const page = await c.env.KV.list<{ steps: number }>({ prefix: k.steps(userId), cursor });
    for (const key of page.keys) {
      const date = key.name.slice(k.steps(userId).length);
      if (date >= from && key.metadata) out.push({ date, steps: key.metadata.steps });
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  out.sort((a, b) => a.date.localeCompare(b.date));
  return c.json({ days: out });
});

garmin.delete("/link", async (c) => {
  const device = requireDevice(c.req.header("X-Meowtrek-Device"));
  if (!device) return c.json({ error: "device_required" }, 401);
  const userId = await c.env.KV.get(k.device(device));
  if (!userId) return c.json({ ok: true });
  const f = c.var.deps.fetch;
  try {
    const token = await accessToken(c.env, f, userId);
    // Garmin requires this call when the app offers its own "disconnect".
    if (token) await f(`${API}/user/registration`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
  } catch (err) {
    console.warn("garmin deregister", (err as Error).message);
  }
  await unlinkUser(c.env, userId);
  return c.json({ ok: true });
});

const Webhook = z.object({
  dailies: z.array(Daily).optional(),
  deregistrations: z.array(z.object({ userId: z.string() })).optional(),
});

garmin.post("/webhook/:key?", async (c) => {
  const secret = c.env.GARMIN_WEBHOOK_SECRET;
  if (secret && c.req.param("key") !== secret) return c.json({ error: "forbidden" }, 403);
  const parsed = Webhook.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);
  const { dailies = [], deregistrations = [] } = parsed.data;
  const f = c.var.deps.fetch;

  const work = (async () => {
    for (const d of deregistrations) await unlinkUser(c.env, d.userId);
    for (const d of dailies) {
      try {
        if (d.callbackURL) await pullPing(c.env, f, d.userId, d.callbackURL);
        else await storeDaily(c.env, d);
      } catch (err) {
        console.error("garmin webhook item", (err as Error).message);
      }
    }
  })();
  // Garmin expects a fast 200; finish the work after responding when running on Workers.
  try {
    c.executionCtx.waitUntil(work);
  } catch {
    await work;
  }
  return c.json({ ok: true });
});
