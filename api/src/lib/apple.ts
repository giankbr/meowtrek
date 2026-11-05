import { Buffer } from "node:buffer";
import { cfg, type Plan } from "../config.js";
import { prisma } from "../db.js";
import { APPLE_ROOT_CA_G3 } from "./appleRoot.js";

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
async function tryVerifiers<T>(
  use: (v: InstanceType<typeof import("@apple/app-store-server-library").SignedDataVerifier>) => Promise<T>,
): Promise<T | null> {
  const { Environment, SignedDataVerifier } = await import("@apple/app-store-server-library");
  const envs = cfg.appleEnv === "Production" ? [Environment.PRODUCTION, Environment.SANDBOX] : [Environment.SANDBOX];
  const roots = [Buffer.from(APPLE_ROOT_CA_G3, "base64")];
  for (const e of envs) {
    try {
      const appId = e === Environment.PRODUCTION ? Number(cfg.appleAppId) : undefined;
      const v = new SignedDataVerifier(roots, false, e, cfg.appleBundleId, appId);
      return await use(v);
    } catch (err) {
      console.warn(`apple verify failed (${e}):`, (err as { status?: unknown }).status ?? (err as Error).message);
    }
  }
  return null;
}

async function verify(jws: string): Promise<TxnPayload | null> {
  if (cfg.allowUnverifiedPlus) return decodeUnverified(jws);
  return tryVerifiers((v) => v.verifyAndDecodeTransaction(jws) as Promise<TxnPayload>);
}

export async function verifyNotification(
  signedPayload: string,
): Promise<{ note: NotificationPayload; txn: TxnPayload | null } | null> {
  if (cfg.allowUnverifiedPlus) {
    const note = decodeUnverified<NotificationPayload>(signedPayload);
    if (!note) return null;
    const txn = note.data?.signedTransactionInfo ? decodeUnverified<TxnPayload>(note.data.signedTransactionInfo) : null;
    return { note, txn };
  }
  return tryVerifiers(async (v) => {
    const note = (await v.verifyAndDecodeNotification(signedPayload)) as NotificationPayload;
    const info = note.data?.signedTransactionInfo;
    const txn = info ? ((await v.verifyAndDecodeTransaction(info)) as TxnPayload) : null;
    return { note, txn };
  });
}

export function isActivePlus(p: TxnPayload | null, now = Date.now()) {
  return !!p && p.bundleId === cfg.appleBundleId && PLUS_PRODUCTS.has(p.productId ?? "") && !p.revocationDate && (p.expiresDate ?? 0) > now;
}

export async function resolvePlan(jws: string | undefined, device?: string): Promise<Plan> {
  // Webhook-recorded state wins: honour refund/revoke/expiry immediately, trust an active record without a JWS.
  if (device) {
    const rec = await prisma.subscription.findUnique({ where: { appAccountToken: device.toLowerCase() } });
    if (rec) {
      if (!rec.active) return "free";
      if (Number(rec.expiresDate ?? 0n) > Date.now()) return "plus";
    }
  }
  if (!jws || jws.length > 20_000 || jws.split(".").length !== 3) return "free";
  const key = (await sha256Hex(jws)).slice(0, 64);
  const cached = await prisma.planCache.findUnique({ where: { key } });
  if (cached && Number(cached.until) > Date.now()) return "plus";

  const payload = await verify(jws);
  if (!isActivePlus(payload)) return "free";
  const until = Math.min(payload!.expiresDate!, Date.now() + CACHE_MAX_MS);
  await prisma.planCache.upsert({ where: { key }, create: { key, until: BigInt(until) }, update: { until: BigInt(until) } });
  return "plus";
}
