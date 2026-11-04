import { describe, expect, it, vi } from "vitest";
import { makeEnv, MemoryKV, setup } from "./helpers";

const garminEnv = (over = {}) => makeEnv({ GARMIN_CONSUMER_KEY: "ck", GARMIN_CONSUMER_SECRET: "cs", ...over });
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

function garminFetch() {
  return vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.includes("/oauth/token")) {
      const p = new URLSearchParams(String(init?.body));
      return json({ access_token: `at-${p.get("grant_type")}`, refresh_token: "rt", expires_in: 86400 });
    }
    if (url.endsWith("/user/id")) return json({ userId: "garmin-user-1" });
    if (url.includes("/user/registration")) return new Response(null, { status: 204 });
    if (url.startsWith("https://apis.garmin.com/wellness-api/rest/dailies"))
      return json([{ calendarDate: "2026-11-04", steps: 4321 }]);
    return new Response("not found", { status: 404 });
  });
}

async function link(env: ReturnType<typeof makeEnv>, f = garminFetch()) {
  const { call } = setup(env, undefined, f as unknown as typeof fetch);
  const auth = await call("/v1/garmin/authorize");
  const { url } = (await auth.json()) as { url: string };
  const state = new URL(url).searchParams.get("state")!;
  const cb = await call(`/v1/garmin/callback?code=abc&state=${state}`, {}, {});
  return { call, auth, url, cb, f };
}

describe("garmin not configured", () => {
  it.each([
    ["GET", "/v1/garmin/authorize"],
    ["GET", "/v1/garmin/callback?code=x&state=y"],
    ["GET", "/v1/garmin/status"],
    ["GET", "/v1/garmin/steps?days=30"],
    ["DELETE", "/v1/garmin/link"],
    ["POST", "/v1/garmin/webhook"],
  ])("%s %s -> 503", async (method, path) => {
    const res = await setup(makeEnv()).call(path, { method });
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "garmin_not_configured" });
  });

  it("503 when only the key is set", async () => {
    const res = await setup(makeEnv({ GARMIN_CONSUMER_KEY: "ck" })).call("/v1/garmin/authorize");
    expect(res.status).toBe(503);
  });
});

describe("garmin oauth2 pkce", () => {
  it("authorize builds a PKCE URL", async () => {
    const { call } = setup(garminEnv());
    const res = await call("/v1/garmin/authorize");
    expect(res.status).toBe(200);
    const url = new URL(((await res.json()) as { url: string }).url);
    expect(url.origin + url.pathname).toBe("https://connect.garmin.com/oauth2Confirm");
    expect(url.searchParams.get("client_id")).toBe("ck");
    expect(url.searchParams.get("code_challenge_method")).toBe("S256");
    expect(url.searchParams.get("code_challenge")).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(url.searchParams.get("redirect_uri")).toBe("http://localhost/v1/garmin/callback");
  });

  it("authorize requires device", async () => {
    const res = await setup(garminEnv()).call("/v1/garmin/authorize", {}, {});
    expect(res.status).toBe(401);
  });

  it("callback exchanges the code and redirects to the app", async () => {
    const env = garminEnv();
    const { cb, f, call } = await link(env);
    expect(cb.status).toBe(302);
    expect(cb.headers.get("location")).toBe("meowtrek://garmin?status=linked");
    const tokenCall = f.mock.calls.find(([u]) => String(u).includes("/oauth/token"))!;
    const body = new URLSearchParams(String(tokenCall[1]?.body));
    expect(body.get("grant_type")).toBe("authorization_code");
    expect(body.get("code_verifier")).toMatch(/^[A-Za-z0-9_-]{43,128}$/);
    expect(await (await call("/v1/garmin/status")).json()).toEqual({ linked: true });
  });

  it("callback: unknown state, denial", async () => {
    const { call } = setup(garminEnv());
    const res = await call("/v1/garmin/callback?code=abc&state=bogus", {}, {});
    expect(res.headers.get("location")).toBe("meowtrek://garmin?status=expired");
    const auth = await call("/v1/garmin/authorize");
    const state = new URL(((await auth.json()) as { url: string }).url).searchParams.get("state");
    const denied = await call(`/v1/garmin/callback?state=${state}&error=access_denied`, {}, {});
    expect(denied.headers.get("location")).toBe("meowtrek://garmin?status=denied");
  });

  it("callback: token failure redirects with error", async () => {
    const f = vi.fn(async () => new Response("bad", { status: 400 }));
    const { cb } = await link(garminEnv(), f as never);
    expect(cb.headers.get("location")).toBe("meowtrek://garmin?status=error");
  });
});

describe("garmin data", () => {
  it("steps 404 when not linked", async () => {
    const res = await setup(garminEnv()).call("/v1/garmin/steps");
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "garmin_not_linked" });
  });

  it("push webhook stores dailies; steps returns the window", async () => {
    const env = garminEnv();
    const { call } = await link(env);
    const d = (offset: number) => new Date(Date.now() - offset * 86_400_000).toISOString().slice(0, 10);
    const push = await call("/v1/garmin/webhook", {
      json: {
        dailies: [
          { userId: "garmin-user-1", summaryId: "x1", calendarDate: d(0), steps: 1200 },
          { userId: "garmin-user-1", summaryId: "x2", calendarDate: d(1), steps: 9000 },
          { userId: "garmin-user-1", summaryId: "x3", calendarDate: d(40), steps: 7000 },
          { userId: "someone-else", calendarDate: d(0), steps: 5 },
        ],
      },
    }, {});
    expect(push.status).toBe(200);
    const res = await call("/v1/garmin/steps?days=30");
    expect(await res.json()).toEqual({ days: [{ date: d(1), steps: 9000 }, { date: d(0), steps: 1200 }] });
    expect(((await (await call("/v1/garmin/steps?days=60")).json()) as { days: unknown[] }).days).toHaveLength(3);
    expect([...(env.KV as unknown as MemoryKV).data.keys()].some((k) => k.includes("someone-else"))).toBe(false);
  });

  it("ping webhook pulls from apis.garmin.com with bearer token, ignores other hosts", async () => {
    const env = garminEnv();
    const { call, f } = await link(env);
    await call("/v1/garmin/webhook", {
      json: {
        dailies: [
          { userId: "garmin-user-1", callbackURL: "https://apis.garmin.com/wellness-api/rest/dailies?uploadStartTimeInSeconds=1&token=t" },
          { userId: "garmin-user-1", callbackURL: "https://evil.example/steal" },
        ],
      },
    }, {});
    const pulls = f.mock.calls.filter(([u]) => String(u).includes("dailies") || String(u).includes("evil"));
    expect(pulls).toHaveLength(1);
    expect((pulls[0][1]?.headers as Record<string, string>).Authorization).toBe("Bearer at-authorization_code");
    const res = await call("/v1/garmin/steps?days=90");
    expect(((await res.json()) as { days: unknown[] }).days.length).toBeLessThanOrEqual(1);
  });

  it("webhook secret is enforced when set", async () => {
    const { call } = setup(garminEnv({ GARMIN_WEBHOOK_SECRET: "s3cret" }));
    expect((await call("/v1/garmin/webhook", { json: {} }, {})).status).toBe(403);
    expect((await call("/v1/garmin/webhook/wrong", { json: {} }, {})).status).toBe(403);
    expect((await call("/v1/garmin/webhook/s3cret", { json: {} }, {})).status).toBe(200);
  });

  it("deregistration webhook and DELETE /link unlink the device", async () => {
    const env = garminEnv();
    const { call, f } = await link(env);
    await call("/v1/garmin/webhook", { json: { deregistrations: [{ userId: "garmin-user-1" }] } }, {});
    expect(await (await call("/v1/garmin/status")).json()).toEqual({ linked: false });

    const again = await link(env, f);
    const del = await again.call("/v1/garmin/link", { method: "DELETE" });
    expect(await del.json()).toEqual({ ok: true });
    expect(f.mock.calls.some(([u, i]) => String(u).endsWith("/user/registration") && i?.method === "DELETE")).toBe(true);
    expect(await (await again.call("/v1/garmin/status")).json()).toEqual({ linked: false });
  });

  it("refreshes an expired access token before pulling", async () => {
    const env = garminEnv();
    const { call, f } = await link(env);
    const kv = env.KV as unknown as MemoryKV;
    const u = JSON.parse(kv.data.get("garmin:user:garmin-user-1")!.value);
    kv.data.set("garmin:user:garmin-user-1", { value: JSON.stringify({ ...u, expiresAt: 0 }) });
    await call("/v1/garmin/webhook", {
      json: { dailies: [{ userId: "garmin-user-1", callbackURL: "https://apis.garmin.com/wellness-api/rest/dailies?x=1" }] },
    }, {});
    const pull = f.mock.calls.find(([url]) => String(url).includes("/rest/dailies"))!;
    expect((pull[1]?.headers as Record<string, string>).Authorization).toBe("Bearer at-refresh_token");
  });
});

