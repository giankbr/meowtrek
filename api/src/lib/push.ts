import { prisma } from "../db.js";
import { type PushAlert, sendPush } from "./apns.js";

// The lifecycle events worth a nudge, and the message each gets.
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

/// Pushes a lifecycle nudge when one fits (called from the App Store webhook).
export async function notifyLifecycle(type: string, subtype: string | undefined, appAccountToken: string | undefined) {
  if (!appAccountToken) return;
  const alert = alertFor(type, subtype);
  if (!alert) return;
  const row = await prisma.pushToken.findUnique({ where: { device: appAccountToken.toLowerCase() } });
  if (!row) return;
  const status = await sendPush(row.token, alert);
  if (status === 410 || status === 400) await prisma.pushToken.delete({ where: { device: appAccountToken.toLowerCase() } }).catch(() => {});
}
