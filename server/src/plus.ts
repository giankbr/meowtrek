import { Buffer } from "node:buffer";
import { APPLE_ROOT_CA_G3 } from "./appleRoot";
import type { Env, Plan } from "./env";

export const PLUS_PRODUCTS = new Set(["id.gian.meowtrek.plus.monthly", "id.gian.meowtrek.plus.yearly"]);
const CACHE_MAX_MS = 60 * 60 * 1000;

interface TxnPayload {
  bundleId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
}

async function sha256Hex(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function decodeUnverified(jws: string): TxnPayload | null {
  try {
    return JSON.parse(Buffer.from(jws.split(".")[1], "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

async function verify(env: Env, jws: string): Promise<TxnPayload | null> {
  if (env.ALLOW_UNVERIFIED_PLUS === "true") return decodeUnverified(jws);
  // Lazy: jsrsasign generates random values at import time, which Workers forbid in global scope.
  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  // Production also accepts Sandbox: App Review and TestFlight purchases are sandbox-signed.
  const envs = env.APPLE_ENVIRONMENT === "Production" ? [Environment.PRODUCTION, Environment.SANDBOX] : [Environment.SANDBOX];
  const roots = [Buffer.from(APPLE_ROOT_CA_G3, "base64")];
  for (const e of envs) {
    try {
      const appId = e === Environment.PRODUCTION ? Number(env.APPLE_APP_ID) : undefined;
      const v = new SignedDataVerifier(roots, false, e, env.APPLE_BUNDLE_ID, appId);
      return await v.verifyAndDecodeTransaction(jws);
    } catch (err) {
      console.warn(`plus verify failed (${e}):`, (err as { status?: unknown }).status ?? (err as Error).message);
    }
  }
  return null;
}

export function isActivePlus(p: TxnPayload | null, bundleId: string, now = Date.now()) {
  return !!p && p.bundleId === bundleId && PLUS_PRODUCTS.has(p.productId ?? "") && !p.revocationDate && (p.expiresDate ?? 0) > now;
}

export async function resolvePlan(env: Env, jws: string | undefined): Promise<Plan> {
  if (!jws || jws.length > 20_000 || jws.split(".").length !== 3) return "free";
  const key = `plus:${await sha256Hex(jws)}`;
  const cached = await env.KV.get(key);
  if (cached && Number(cached) > Date.now()) return "plus";

  const payload = await verify(env, jws);
  if (!isActivePlus(payload, env.APPLE_BUNDLE_ID)) return "free";
  const until = Math.min(payload!.expiresDate!, Date.now() + CACHE_MAX_MS);
  const ttl = Math.max(60, Math.floor((until - Date.now()) / 1000));
  await env.KV.put(key, String(until), { expirationTtl: ttl });
  return "plus";
}
