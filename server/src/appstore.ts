import { Hono } from "hono";
import { today, type AppEnv, type Env } from "./env";
import { isActivePlus, verifyNotification } from "./plus";

// App Store Server Notifications V2: Apple POSTs subscription lifecycle events here so we have
// server-side truth about renewals, refunds and cancellations without waiting for the app to open.
export const appstore = new Hono<AppEnv>();

const SUB_TTL = 400 * 24 * 3600;
const INACTIVE_TYPES = new Set(["REFUND", "REVOKE", "EXPIRED", "GRACE_PERIOD_EXPIRED"]);

async function bump(env: Env, key: string) {
  const n = Number((await env.KV.get(key)) ?? 0) + 1;
  await env.KV.put(key, String(n), { expirationTtl: SUB_TTL });
}

appstore.post("/notifications", async (c) => {
  const body = (await c.req.json().catch(() => null)) as { signedPayload?: string } | null;
  if (!body?.signedPayload || typeof body.signedPayload !== "string") return c.json({ error: "invalid_request" }, 400);

  const result = await verifyNotification(c.env, body.signedPayload);
  if (!result?.note) return c.json({ error: "invalid_signature" }, 400);

  const { note, txn } = result;
  const type = note.notificationType ?? "UNKNOWN";
  await bump(c.env, `tm:asn:${today()}:${type}${note.subtype ? `.${note.subtype}` : ""}`);

  if (txn) {
    const active = isActivePlus(txn, c.env.APPLE_BUNDLE_ID) && !INACTIVE_TYPES.has(type);
    const record = JSON.stringify({
      active,
      type,
      subtype: note.subtype ?? null,
      productId: txn.productId ?? null,
      expiresDate: txn.expiresDate ?? null,
      originalTransactionId: txn.originalTransactionId ?? null,
      updatedAt: Date.now(),
    });
    const keys: string[] = [];
    if (txn.appAccountToken) keys.push(`sub:acct:${txn.appAccountToken}`);
    if (txn.originalTransactionId) keys.push(`sub:tx:${txn.originalTransactionId}`);
    await Promise.all(keys.map((k) => c.env.KV.put(k, record, { expirationTtl: SUB_TTL })));
  }

  return c.json({ ok: true }); // Apple expects a 2xx or it will retry.
});

// Look up the latest known subscription state for an install (by its appAccountToken).
export async function plusRecord(env: Env, accountToken: string) {
  return env.KV.get(`sub:acct:${accountToken}`, "json");
}
