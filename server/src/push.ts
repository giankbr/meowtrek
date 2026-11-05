import { Hono } from "hono";
import { z } from "zod";
import { type PushAlert, sendPush } from "./apns";
import type { AppEnv, Env } from "./env";

// Stores a device's APNs token (keyed by its install id) and sends subscription-lifecycle pushes.
export const push = new Hono<AppEnv>();

const TOKEN_TTL = 120 * 24 * 3600;
const tokenKey = (device: string) => `push:${device.toLowerCase()}`;

const RegisterBody = z.object({ token: z.string().regex(/^[0-9a-fA-F]{64}$/) });

function device(c: { req: { header: (k: string) => string | undefined } }): string | null {
  const d = c.req.header("X-Meowtrek-Device");
  return d && /^[0-9A-Fa-f-]{8,64}$/.test(d) ? d : null;
}

push.post("/register", async (c) => {
  const dev = device(c);
  if (!dev) return c.json({ error: "no_device" }, 400);
  const parsed = RegisterBody.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);
  await c.env.KV.put(tokenKey(dev), parsed.data.token.toLowerCase(), { expirationTtl: TOKEN_TTL });
  return c.json({ ok: true });
});

push.post("/unregister", async (c) => {
  const dev = device(c);
  if (!dev) return c.json({ error: "no_device" }, 400);
  await c.env.KV.delete(tokenKey(dev));
  return c.json({ ok: true });
});

// The lifecycle events worth a nudge, and the message each one gets.
function alertFor(type: string, subtype: string | undefined): PushAlert | null {
  switch (type) {
    case "EXPIRED":
      return { title: "Your cat misses you", body: "Meowtrek Plus has ended — come back for unlimited chats, 1.5× coins and a monthly gift." };
    case "GRACE_PERIOD_EXPIRED":
      return { title: "A hiccup with Plus", body: "We couldn't renew your Plus. Update your payment to keep your perks." };
    case "DID_CHANGE_RENEWAL_STATUS":
      return subtype === "AUTO_RENEW_DISABLED"
        ? { title: "Plus is set to end", body: "Turn renew back on to keep unlimited chats and your companion cat." }
        : null;
    default:
      return null;
  }
}

/// Called from the App Store notification webhook: pushes a lifecycle nudge when one fits.
export async function notifyLifecycle(
  env: Env,
  fetchImpl: typeof fetch,
  type: string,
  subtype: string | undefined,
  appAccountToken: string | undefined,
): Promise<void> {
  if (!appAccountToken) return;
  const alert = alertFor(type, subtype);
  if (!alert) return;
  const token = await env.KV.get(tokenKey(appAccountToken));
  if (!token) return;
  const status = await sendPush(env, fetchImpl, token, alert);
  if (status === 410 || status === 400) await env.KV.delete(tokenKey(appAccountToken)); // token no longer valid
}
