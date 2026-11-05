// Garmin Connect Developer Program (Health API), OAuth 2.0 PKCE. Ported from the Worker version.
import { Buffer } from "node:buffer";
import { type Request, type Response, Router } from "express";
import { z } from "zod";
import { cfg, today } from "../config.js";
import { prisma } from "../db.js";
import { Device } from "../schemas.js";

const AUTHORIZE_URL = "https://connect.garmin.com/oauth2Confirm";
const TOKEN_URL = "https://connectapi.garmin.com/di-oauth2-service/oauth/token";
const API = "https://apis.garmin.com/wellness-api/rest";
const APP_REDIRECT = "meowtrek://garmin";

const b64url = (buf: ArrayBuffer | Uint8Array) => Buffer.from(buf instanceof Uint8Array ? buf : new Uint8Array(buf)).toString("base64url");

export const garmin = Router();

export const configured = () => !!(cfg.garminKey && cfg.garminSecret);

const TokenRes = z.object({ access_token: z.string(), refresh_token: z.string(), expires_in: z.number() });

async function tokenRequest(params: Record<string, string>) {
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: cfg.garminKey!, client_secret: cfg.garminSecret!, ...params }),
  });
  if (!res.ok) throw new Error(`garmin token ${res.status}`);
  const t = TokenRes.parse(await res.json());
  return { accessToken: t.access_token, refreshToken: t.refresh_token, expiresAt: Date.now() + (t.expires_in - 600) * 1000 };
}

async function accessToken(userId: string): Promise<string | null> {
  const user = await prisma.garminUser.findUnique({ where: { userId } });
  if (!user) return null;
  if (Number(user.expiresAt) > Date.now()) return user.accessToken;
  const t = await tokenRequest({ grant_type: "refresh_token", refresh_token: user.refreshToken });
  await prisma.garminUser.update({ where: { userId }, data: { accessToken: t.accessToken, refreshToken: t.refreshToken, expiresAt: BigInt(t.expiresAt) } });
  return t.accessToken;
}

async function unlinkUser(userId: string) {
  await prisma.garminUser.deleteMany({ where: { userId } }); // cascades devices + steps
}

const Daily = z.object({
  userId: z.string(),
  calendarDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  steps: z.number().int().min(0).optional(),
  callbackURL: z.string().optional(),
});

async function storeDaily(d: z.infer<typeof Daily>) {
  if (!d.calendarDate || d.steps === undefined) return;
  if (!(await prisma.garminUser.findUnique({ where: { userId: d.userId } }))) return;
  await prisma.garminSteps.upsert({
    where: { userId_date: { userId: d.userId, date: d.calendarDate } },
    create: { userId: d.userId, date: d.calendarDate, steps: d.steps },
    update: { steps: d.steps },
  });
}

async function pullPing(userId: string, callbackURL: string) {
  const url = new URL(callbackURL);
  if (url.protocol !== "https:" || url.hostname !== "apis.garmin.com") return;
  const token = await accessToken(userId);
  if (!token) return;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`garmin ping pull ${res.status}`);
  const list = z.array(Daily.partial({ userId: true })).parse(await res.json());
  for (const d of list) await storeDaily({ ...d, userId: d.userId ?? userId });
}

garmin.use((_req, res, next) => {
  if (!configured()) return res.status(503).json({ error: "garmin_not_configured" });
  next();
});

const requireDevice = (h: string | undefined) => (Device.safeParse(h).success ? h! : null);

garmin.get("/authorize", async (req, res) => {
  const device = requireDevice(req.header("X-Meowtrek-Device"));
  if (!device) return res.status(401).json({ error: "device_required" });
  const verifier = b64url(crypto.getRandomValues(new Uint8Array(48)));
  const challenge = b64url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
  const state = b64url(crypto.getRandomValues(new Uint8Array(24)));
  const redirectUri = `${req.protocol}://${req.get("host")}/v1/garmin/callback`;
  await prisma.garminState.create({ data: { state, device, verifier, redirectUri } });
  const url = new URL(AUTHORIZE_URL);
  url.search = new URLSearchParams({
    response_type: "code",
    client_id: cfg.garminKey!,
    code_challenge: challenge,
    code_challenge_method: "S256",
    redirect_uri: redirectUri,
    state,
  }).toString();
  res.json({ url: url.toString() });
});

garmin.get("/callback", async (req, res) => {
  const back = (status: string) => res.redirect(302, `${APP_REDIRECT}?status=${status}`);
  const code = req.query.code as string | undefined;
  const state = req.query.state as string | undefined;
  if (!state) return back("error");
  const saved = await prisma.garminState.findUnique({ where: { state } });
  await prisma.garminState.deleteMany({ where: { state } });
  if (!saved) return back("expired");
  if (!code) return back("denied");
  try {
    const t = await tokenRequest({ grant_type: "authorization_code", code, code_verifier: saved.verifier, redirect_uri: saved.redirectUri });
    const idRes = await fetch(`${API}/user/id`, { headers: { Authorization: `Bearer ${t.accessToken}` } });
    if (!idRes.ok) throw new Error(`garmin user id ${idRes.status}`);
    const { userId } = z.object({ userId: z.string().min(1) }).parse(await idRes.json());

    const prev = await prisma.garminDevice.findUnique({ where: { device: saved.device } });
    if (prev && prev.userId !== userId) await unlinkUser(prev.userId);
    await prisma.garminUser.upsert({
      where: { userId },
      create: { userId, accessToken: t.accessToken, refreshToken: t.refreshToken, expiresAt: BigInt(t.expiresAt) },
      update: { accessToken: t.accessToken, refreshToken: t.refreshToken, expiresAt: BigInt(t.expiresAt) },
    });
    await prisma.garminDevice.upsert({ where: { device: saved.device }, create: { device: saved.device, userId }, update: { userId } });
    return back("linked");
  } catch (err) {
    console.error("garmin callback", (err as Error).message);
    return back("error");
  }
});

garmin.get("/status", async (req, res) => {
  const device = requireDevice(req.header("X-Meowtrek-Device"));
  if (!device) return res.status(401).json({ error: "device_required" });
  res.json({ linked: !!(await prisma.garminDevice.findUnique({ where: { device } })) });
});

garmin.get("/steps", async (req, res) => {
  const device = requireDevice(req.header("X-Meowtrek-Device"));
  if (!device) return res.status(401).json({ error: "device_required" });
  const days = z.coerce.number().int().min(1).max(90).catch(30).parse(req.query.days ?? 30);
  const link = await prisma.garminDevice.findUnique({ where: { device } });
  if (!link) return res.status(404).json({ error: "garmin_not_linked" });
  const from = today(new Date(Date.now() - (days - 1) * 86_400_000));
  const rows = await prisma.garminSteps.findMany({ where: { userId: link.userId, date: { gte: from } }, orderBy: { date: "asc" }, select: { date: true, steps: true } });
  res.json({ days: rows });
});

garmin.delete("/link", async (req, res) => {
  const device = requireDevice(req.header("X-Meowtrek-Device"));
  if (!device) return res.status(401).json({ error: "device_required" });
  const link = await prisma.garminDevice.findUnique({ where: { device } });
  if (!link) return res.json({ ok: true });
  try {
    const token = await accessToken(link.userId);
    if (token) await fetch(`${API}/user/registration`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
  } catch (err) {
    console.warn("garmin deregister", (err as Error).message);
  }
  await unlinkUser(link.userId);
  res.json({ ok: true });
});

const Webhook = z.object({
  dailies: z.array(Daily).optional(),
  deregistrations: z.array(z.object({ userId: z.string() })).optional(),
});

async function handleWebhook(req: Request, res: Response) {
  if (cfg.garminWebhookSecret && req.params.key !== cfg.garminWebhookSecret) return res.status(403).json({ error: "forbidden" });
  const parsed = Webhook.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
  res.json({ ok: true }); // respond fast; finish work after
  const { dailies = [], deregistrations = [] } = parsed.data;
  for (const d of deregistrations) await unlinkUser(d.userId).catch(() => {});
  for (const d of dailies) {
    try {
      if (d.callbackURL) await pullPing(d.userId, d.callbackURL);
      else await storeDaily(d);
    } catch (err) {
      console.error("garmin webhook item", (err as Error).message);
    }
  }
}

garmin.post("/webhook", handleWebhook);
garmin.post("/webhook/:key", handleWebhook);
