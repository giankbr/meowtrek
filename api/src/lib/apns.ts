import { Buffer } from "node:buffer";
import { cfg } from "../config.js";

export function apnsConfigured(): boolean {
  return !!(cfg.apnsKey && cfg.apnsKeyId && cfg.apnsTeamId);
}

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data instanceof Uint8Array ? data : new Uint8Array(data);
  return Buffer.from(bytes).toString("base64url");
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----BEGIN [^-]+-----/g, "").replace(/-----END [^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(Buffer.from(body, "base64")).buffer;
}

let cachedJwt: { token: string; at: number } | null = null;

async function providerToken(): Promise<string> {
  if (cachedJwt && Date.now() - cachedJwt.at < 50 * 60 * 1000) return cachedJwt.token;
  const header = b64url(JSON.stringify({ alg: "ES256", kid: cfg.apnsKeyId }));
  const payload = b64url(JSON.stringify({ iss: cfg.apnsTeamId, iat: Math.floor(Date.now() / 1000) }));
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(cfg.apnsKey!), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));
  const token = `${signingInput}.${b64url(sig)}`;
  cachedJwt = { token, at: Date.now() };
  return token;
}

export interface PushAlert {
  title: string;
  body: string;
}

/// Sends one alert push. Returns the HTTP status, or 0 if APNs isn't configured.
export async function sendPush(token: string, alert: PushAlert): Promise<number> {
  if (!apnsConfigured()) return 0;
  const host = (cfg.apnsEnv ?? cfg.appleEnv) === "Production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const jwt = await providerToken();
  const res = await fetch(`https://${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": cfg.apnsTopic ?? cfg.appleBundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify({ aps: { alert, sound: "default" } }),
  });
  return res.status;
}
