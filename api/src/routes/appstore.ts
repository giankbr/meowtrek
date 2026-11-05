import { Router } from "express";
import { today } from "../config.js";
import { prisma } from "../db.js";
import { isActivePlus, verifyNotification } from "../lib/apple.js";
import { notifyLifecycle } from "../lib/push.js";

export const appstore = Router();

const INACTIVE_TYPES = new Set(["REFUND", "REVOKE", "EXPIRED", "GRACE_PERIOD_EXPIRED"]);

async function bumpCounter(type: string, subtype: string | null) {
  const id = `asn:${today()}:${type}${subtype ? `.${subtype}` : ""}`;
  await prisma.telemetryCounter.upsert({
    where: { id },
    create: { id, date: today(), name: `${type}${subtype ? `.${subtype}` : ""}`, count: 1 },
    update: { count: { increment: 1 } },
  });
}

appstore.post("/notifications", async (req, res) => {
  const signedPayload = req.body?.signedPayload;
  if (!signedPayload || typeof signedPayload !== "string") return res.status(400).json({ error: "invalid_request" });

  const result = await verifyNotification(signedPayload);
  if (!result?.note) return res.status(400).json({ error: "invalid_signature" });

  const { note, txn } = result;
  const type = note.notificationType ?? "UNKNOWN";
  await bumpCounter(type, note.subtype ?? null);

  if (txn && txn.originalTransactionId) {
    const active = isActivePlus(txn) && !INACTIVE_TYPES.has(type);
    const data = {
      active,
      appAccountToken: txn.appAccountToken ? txn.appAccountToken.toLowerCase() : null,
      productId: txn.productId ?? null,
      type,
      subtype: note.subtype ?? null,
      expiresDate: txn.expiresDate ? BigInt(txn.expiresDate) : null,
    };
    await prisma.subscription.upsert({
      where: { originalTransactionId: txn.originalTransactionId },
      create: { originalTransactionId: txn.originalTransactionId, ...data },
      update: data,
    });
    await notifyLifecycle(type, note.subtype, txn.appAccountToken);
  }

  res.json({ ok: true }); // Apple expects a 2xx or it retries.
});
