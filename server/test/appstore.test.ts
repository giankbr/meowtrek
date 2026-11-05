import { describe, expect, it } from "vitest";
import { fakeJws, makeEnv, setup } from "./helpers";

const future = Date.now() + 30 * 86_400_000;
const past = Date.now() - 86_400_000;

const txn = (over: object = {}) =>
  fakeJws({
    bundleId: "id.gian.meowtrek",
    productId: "id.gian.meowtrek.plus.monthly",
    expiresDate: future,
    originalTransactionId: "100001",
    appAccountToken: "tok-123",
    ...over,
  });

const notification = (type: string, txnJws: string, subtype?: string) =>
  fakeJws({ notificationType: type, subtype, data: { signedTransactionInfo: txnJws } });

const env = () => makeEnv({ ALLOW_UNVERIFIED_PLUS: "true" });

describe("app store server notifications", () => {
  it("records an active subscription on DID_RENEW", async () => {
    const e = env();
    const res = await setup(e).call("/v1/appstore/notifications", { json: { signedPayload: notification("DID_RENEW", txn()) } });
    expect(res.status).toBe(200);
    const rec = (await e.KV.get("sub:acct:tok-123", "json")) as { active: boolean; type: string };
    expect(rec.active).toBe(true);
    expect(rec.type).toBe("DID_RENEW");
    expect(await e.KV.get("sub:tx:100001", "json")).not.toBeNull();
  });

  it("marks inactive on REFUND even with a future expiry", async () => {
    const e = env();
    await setup(e).call("/v1/appstore/notifications", { json: { signedPayload: notification("REFUND", txn()) } });
    const rec = (await e.KV.get("sub:acct:tok-123", "json")) as { active: boolean };
    expect(rec.active).toBe(false);
  });

  it("marks inactive when the subscription has expired", async () => {
    const e = env();
    await setup(e).call("/v1/appstore/notifications", { json: { signedPayload: notification("EXPIRED", txn({ expiresDate: past })) } });
    const rec = (await e.KV.get("sub:acct:tok-123", "json")) as { active: boolean };
    expect(rec.active).toBe(false);
  });

  it("counts the notification type", async () => {
    const e = env();
    await setup(e).call("/v1/appstore/notifications", { json: { signedPayload: notification("SUBSCRIBED", txn(), "INITIAL_BUY") } });
    const keys = (await e.KV.list({ prefix: "tm:asn:" })).keys;
    expect(keys.some((k) => k.name.includes("SUBSCRIBED.INITIAL_BUY"))).toBe(true);
  });

  it("rejects a request with no payload", async () => {
    const res = await setup(env()).call("/v1/appstore/notifications", { json: {} });
    expect(res.status).toBe(400);
  });
});
