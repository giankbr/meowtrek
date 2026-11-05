import { Buffer } from "node:buffer";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { DEVICE, fakeJws, makeEnv, setup } from "./helpers";

const TOKEN = "a".repeat(64);
const future = Date.now() + 30 * 86_400_000;

// A throwaway P-256 key so the JWT signing path runs for real in tests.
let APNS_KEY = "";
beforeAll(async () => {
  const kp = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", kp.privateKey);
  APNS_KEY = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(pkcs8).toString("base64")}\n-----END PRIVATE KEY-----`;
});

const apnsEnv = () =>
  makeEnv({ ALLOW_UNVERIFIED_PLUS: "true", APNS_KEY, APNS_KEY_ID: "KID123", APNS_TEAM_ID: "TEAM12" });

const txn = (over: object = {}) =>
  fakeJws({ bundleId: "id.gian.meowtrek", productId: "id.gian.meowtrek.plus.monthly", expiresDate: future, appAccountToken: DEVICE, ...over });
const notification = (type: string, subtype?: string) =>
  fakeJws({ notificationType: type, subtype, data: { signedTransactionInfo: txn() } });

describe("push registration", () => {
  it("stores and clears a device token", async () => {
    const e = makeEnv();
    const s = setup(e);
    expect((await s.call("/v1/push/register", { json: { token: TOKEN } })).status).toBe(200);
    expect(await e.KV.get(`push:${DEVICE.toLowerCase()}`)).toBe(TOKEN);
    await s.call("/v1/push/unregister", { json: {} });
    expect(await e.KV.get(`push:${DEVICE.toLowerCase()}`)).toBeNull();
  });

  it("rejects a malformed token", async () => {
    expect((await setup(makeEnv()).call("/v1/push/register", { json: { token: "nope" } })).status).toBe(400);
  });
});

describe("lifecycle pushes", () => {
  it("sends an APNs alert on EXPIRED when a token is registered", async () => {
    const e = apnsEnv();
    await e.KV.put(`push:${DEVICE.toLowerCase()}`, TOKEN);
    const fetchMock = vi.fn(async () => new Response(null, { status: 200 }));
    const s = setup(e, undefined, fetchMock as unknown as typeof fetch);
    const res = await s.call("/v1/appstore/notifications", { json: { signedPayload: notification("EXPIRED") } });
    expect(res.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe(`https://api.sandbox.push.apple.com/3/device/${TOKEN}`);
    expect(String((init.headers as Record<string, string>).authorization)).toMatch(/^bearer /);
    expect(JSON.parse(String(init.body)).aps.alert.title).toBeTruthy();
  });

  it("does not push for a routine renewal", async () => {
    const e = apnsEnv();
    await e.KV.put(`push:${DEVICE.toLowerCase()}`, TOKEN);
    const fetchMock = vi.fn(async () => new Response(null, { status: 200 }));
    await setup(e, undefined, fetchMock as unknown as typeof fetch).call("/v1/appstore/notifications", {
      json: { signedPayload: notification("DID_RENEW") },
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("drops a token APNs rejects with 410", async () => {
    const e = apnsEnv();
    await e.KV.put(`push:${DEVICE.toLowerCase()}`, TOKEN);
    const fetchMock = vi.fn(async () => new Response(null, { status: 410 }));
    await setup(e, undefined, fetchMock as unknown as typeof fetch).call("/v1/appstore/notifications", {
      json: { signedPayload: notification("EXPIRED") },
    });
    expect(await e.KV.get(`push:${DEVICE.toLowerCase()}`)).toBeNull();
  });
});
