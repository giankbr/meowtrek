import { Buffer } from "node:buffer";
import type { Env } from "./env";

// Minimal APNs HTTP/2 sender for Cloudflare Workers, using token (JWT ES256) auth.

export function apnsConfigured(env: Env): boolean {
  return !!(env.APNS_KEY && env.APNS_KEY_ID && env.APNS_TEAM_ID);
}

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data instanceof Uint8Array ? data : new Uint8Array(data);
  return Buffer.from(bytes).toString("base64url");
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(Buffer.from(body, "base64")).buffer;
}

// APNs allows a provider token to be reused for up to an hour; cache it so we don't re-sign per push.
async function providerToken(env: Env): Promise<string> {
  const cached = await env.KV.get("apns:jwt");
  if (cached) return cached;
  const header = b64url(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID }));
  const payload = b64url(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(env.APNS_KEY!), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));
  const jwt = `${signingInput}.${b64url(sig)}`;
  await env.KV.put("apns:jwt", jwt, { expirationTtl: 50 * 60 });
  return jwt;
}

export interface PushAlert {
  title: string;
  body: string;
}

/// Sends one alert push. Returns the HTTP status, or 0 if APNs isn't configured.
export async function sendPush(env: Env, fetchImpl: typeof fetch, token: string, alert: PushAlert): Promise<number> {
  if (!apnsConfigured(env)) return 0;
  const host = (env.APNS_ENVIRONMENT ?? env.APPLE_ENVIRONMENT) === "Production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const jwt = await providerToken(env);
  const res = await fetchImpl(`https://${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": env.APNS_TOPIC ?? env.APPLE_BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify({ aps: { alert, sound: "default" } }),
  });
  return res.status;
}
