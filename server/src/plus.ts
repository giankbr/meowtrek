import { Buffer } from "node:buffer";
import { APPLE_ROOT_CA_G3 } from "./appleRoot";
import type { Env, Plan } from "./env";

export const PLUS_PRODUCTS = new Set(["id.gian.meowtrek.plus.monthly", "id.gian.meowtrek.plus.yearly"]);
const CACHE_MAX_MS = 60 * 60 * 1000;

export interface TxnPayload {
  bundleId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  originalTransactionId?: string;
  appAccountToken?: string;
}

export interface NotificationPayload {
  notificationType?: string;
  subtype?: string;
  notificationUUID?: string;
  data?: { signedTransactionInfo?: string; signedRenewalInfo?: string; bundleId?: string };
}

async function sha256Hex(s: string) {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function decodeUnverified<T = TxnPayload>(jws: string): T | null {
  try {
    return JSON.parse(Buffer.from(jws.split(".")[1], "base64url").toString("utf8")) as T;
  } catch {
    return null;
  }
}

// Runs `use` against a verifier for each candidate environment, returning the first success.
// Lazy import: jsrsasign generates random values at import time, which Workers forbid in global scope.
async function tryVerifiers<T>(env: Env, use: (v: InstanceType<typeof import("@apple/app-store-server-library").SignedDataVerifier>) => Promise<T>): Promise<T | null> {
  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  // Production also accepts Sandbox: App Review and TestFlight purchases are sandbox-signed.
  const envs = env.APPLE_ENVIRONMENT === "Production" ? [Environment.PRODUCTION, Environment.SANDBOX] : [Environment.SANDBOX];
  const roots = [Buffer.from(APPLE_ROOT_CA_G3, "base64")];
  for (const e of envs) {
    try {
      const appId = e === Environment.PRODUCTION ? Number(env.APPLE_APP_ID) : undefined;
      const v = new SignedDataVerifier(roots, false, e, env.APPLE_BUNDLE_ID, appId);
      return await use(v);
    } catch (err) {
      console.warn(`apple verify failed (${e}):`, (err as { status?: unknown }).status ?? (err as Error).message);
    }
  }
  return null;
}

async function verify(env: Env, jws: string): Promise<TxnPayload | null> {
  if (env.ALLOW_UNVERIFIED_PLUS === "true") return decodeUnverified(jws);
  return tryVerifiers(env, (v) => v.verifyAndDecodeTransaction(jws) as Promise<TxnPayload>);
}

/// Verifies an App Store Server Notification V2 and the transaction it carries.
export async function verifyNotification(
  env: Env,
  signedPayload: string,
): Promise<{ note: NotificationPayload; txn: TxnPayload | null } | null> {
  if (env.ALLOW_UNVERIFIED_PLUS === "true") {
    const note = decodeUnverified<NotificationPayload>(signedPayload);
    if (!note) return null;
    const txn = note.data?.signedTransactionInfo ? decodeUnverified<TxnPayload>(note.data.signedTransactionInfo) : null;
    return { note, txn };
  }
  return tryVerifiers(env, async (v) => {
    const note = (await v.verifyAndDecodeNotification(signedPayload)) as NotificationPayload;
    const info = note.data?.signedTransactionInfo;
    const txn = info ? ((await v.verifyAndDecodeTransaction(info)) as TxnPayload) : null;
    return { note, txn };
  });
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
