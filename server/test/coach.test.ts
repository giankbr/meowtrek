import Anthropic from "@anthropic-ai/sdk";
import { describe, expect, it } from "vitest";
import { context, DEVICE, fakeJws, makeEnv, mockClaude, setup } from "./helpers";

const chatBody = { messages: [{ role: "user", content: "halo Mochi" }], context };
const future = Date.now() + 30 * 86_400_000;
const plusTxn = (over: object = {}) =>
  fakeJws({ bundleId: "id.gian.meowtrek", productId: "id.gian.meowtrek.plus.monthly", expiresDate: future, ...over });

describe("basics", () => {
  it("health", async () => {
    const res = await setup(makeEnv()).call("/v1/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
  });

  it("unknown route is JSON 404", async () => {
    const res = await setup(makeEnv()).call("/nope");
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "not_found" });
  });
});

describe("coach auth & validation", () => {
  it("requires a UUID device header", async () => {
    const { call } = setup(makeEnv());
    for (const headers of [{}, { "X-Meowtrek-Device": "abc" }] as Record<string, string>[]) {
      const res = await call("/v1/coach/chat", { json: chatBody }, headers);
      expect(res.status).toBe(401);
      expect(await res.json()).toEqual({ error: "device_required" });
    }
  });

  it("503 when ANTHROPIC_API_KEY is missing", async () => {
    const res = await setup(makeEnv({ ANTHROPIC_API_KEY: undefined })).call("/v1/coach/chat", { json: chatBody });
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "ai_not_configured" });
  });

  it.each([
    ["weekSteps wrong length", { ...chatBody, context: { ...context, weekSteps: [1, 2, 3] } }],
    ["last message from assistant", { ...chatBody, messages: [{ role: "assistant", content: "hi" }] }],
    ["empty messages", { ...chatBody, messages: [] }],
    ["negative steps", { ...chatBody, context: { ...context, todaySteps: -1 } }],
    ["missing context", { messages: chatBody.messages }],
  ])("400 on %s", async (_name, body) => {
    const { client, create } = mockClaude();
    const res = await setup(makeEnv(), client).call("/v1/coach/chat", { json: body });
    expect(res.status).toBe(400);
    const json = (await res.json()) as { error: string; issues: unknown[] };
    expect(json.error).toBe("invalid_request");
    expect(json.issues.length).toBeGreaterThan(0);
    expect(create).not.toHaveBeenCalled();
  });

  it("400 on malformed JSON", async () => {
    const res = await setup(makeEnv()).call("/v1/coach/chat", { method: "POST", body: "{nope" });
    expect(res.status).toBe(400);
  });
});

describe("chat", () => {
  it("replies and passes model, fallback and Indonesian persona", async () => {
    const { client, create } = mockClaude({ text: "  Purr! Ayo jalan 2000 langkah lagi.  " });
    const res = await setup(makeEnv(), client).call("/v1/coach/chat", { json: chatBody });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ reply: "Purr! Ayo jalan 2000 langkah lagi." });
    expect(res.headers.get("X-Remaining")).toBe("4");
    expect(res.headers.get("X-Plan")).toBe("free");
    const args = (create.mock.calls[0] as unknown[])[0] as Record<string, unknown>;
    expect(args.model).toBe("claude-opus-5-5");
    expect(args.fallbacks).toBe("default");
    expect(args.system).toContain("Indonesian");
    expect(args.system).toContain("Mochi");
  });

  it("drops leading assistant turns when trimming history", async () => {
    const { client, create } = mockClaude();
    const messages = Array.from({ length: 25 }, (_, i) => ({ role: i % 2 ? "assistant" : "user", content: `m${i}` }));
    await setup(makeEnv(), client).call("/v1/coach/chat", { json: { ...chatBody, messages } });
    const sent = ((create.mock.calls[0] as unknown[])[0] as { messages: { role: string }[] }).messages;
    expect(sent[0].role).toBe("user");
    expect(sent.length).toBeLessThanOrEqual(20);
  });

  it("returns an in-character line on refusal", async () => {
    const { client } = mockClaude({ stop_reason: "refusal", text: "" });
    const res = await setup(makeEnv(), client).call("/v1/coach/chat", { json: chatBody });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { reply: string }).reply).toMatch(/Meow/);
  });

  it("503 ai_busy on upstream 5xx without consuming quota", async () => {
    const { client, create } = mockClaude();
    create.mockRejectedValueOnce(new Anthropic.InternalServerError(500, undefined, "boom", new Headers()));
    const env = makeEnv();
    const { call } = setup(env, client);
    const res = await call("/v1/coach/chat", { json: chatBody });
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "ai_busy" });
    const ok = await call("/v1/coach/chat", { json: chatBody });
    expect(ok.headers.get("X-Remaining")).toBe("4");
  });
});

describe("rate limiting", () => {
  it("free: 5 chats per day, then 429", async () => {
    const { client, create } = mockClaude();
    const { call } = setup(makeEnv(), client);
    for (let i = 0; i < 5; i++) {
      const res = await call("/v1/coach/chat", { json: chatBody });
      expect(res.status).toBe(200);
      expect(res.headers.get("X-Remaining")).toBe(String(4 - i));
    }
    const res = await call("/v1/coach/chat", { json: chatBody });
    expect(res.status).toBe(429);
    expect(res.headers.get("X-Remaining")).toBe("0");
    expect(await res.json()).toEqual({ error: "limit", remaining: 0 });
    expect(create).toHaveBeenCalledTimes(5);
  });

  it("limits are per device", async () => {
    const { call } = setup(makeEnv());
    for (let i = 0; i < 5; i++) await call("/v1/coach/chat", { json: chatBody });
    const other = await call("/v1/coach/chat", { json: chatBody }, { "X-Meowtrek-Device": "11111111-2222-4333-8444-555555555555" });
    expect(other.status).toBe(200);
  });

  it("chat and quests have separate buckets", async () => {
    const { call } = setup(makeEnv(), mockClaude({ parsed: { quests: [] } }).client);
    for (let i = 0; i < 5; i++) await call("/v1/coach/chat", { json: chatBody });
    const res = await call("/v1/coach/quests", { json: { context } });
    expect(res.status).toBe(200);
    expect(res.headers.get("X-Remaining")).toBe("2");
  });

  it("plus (unverified dev mode) gets 200/day", async () => {
    const res = await setup(makeEnv({ ALLOW_UNVERIFIED_PLUS: "true" })).call("/v1/coach/chat", { json: chatBody }, {
      "X-Meowtrek-Device": DEVICE,
      "X-Meowtrek-Transaction": plusTxn(),
    });
    expect(res.headers.get("X-Plan")).toBe("plus");
    expect(res.headers.get("X-Remaining")).toBe("199");
  });

  it.each([
    ["expired", { expiresDate: Date.now() - 1000 }],
    ["revoked", { revocationDate: Date.now() - 1000 }],
    ["other product", { productId: "id.gian.meowtrek.coins" }],
    ["other bundle", { bundleId: "com.example.app" }],
  ])("%s transaction stays free", async (_n, over) => {
    const res = await setup(makeEnv({ ALLOW_UNVERIFIED_PLUS: "true" })).call("/v1/coach/chat", { json: chatBody }, {
      "X-Meowtrek-Device": DEVICE,
      "X-Meowtrek-Transaction": plusTxn(over),
    });
    expect(res.headers.get("X-Plan")).toBe("free");
  });

  it("unsigned transaction is rejected when verification is on", async () => {
    const res = await setup(makeEnv()).call("/v1/coach/chat", { json: chatBody }, {
      "X-Meowtrek-Device": DEVICE,
      "X-Meowtrek-Transaction": plusTxn(),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("X-Plan")).toBe("free");
  });
});

describe("insight", () => {
  const body = { context, last28Days: Array.from({ length: 28 }, (_, i) => 4000 + i * 100) };

  it("validates 28 days", async () => {
    const res = await setup(makeEnv()).call("/v1/coach/insight", { json: { ...body, last28Days: [1, 2] } });
    expect(res.status).toBe(400);
  });

  it("normalizes model output", async () => {
    const parsed = { headline: "Great week!", summary: "You walked more.", tips: ["a", "b", "c", "d"], suggestedGoal: 123_456 };
    const res = await setup(makeEnv(), mockClaude({ parsed }).client).call("/v1/coach/insight", { json: body });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ headline: "Great week!", summary: "You walked more.", tips: ["a", "b", "c"], suggestedGoal: 30_000 });
  });

  it("502 when the model gives no usable output", async () => {
    const res = await setup(makeEnv(), mockClaude({ parsed: null }).client).call("/v1/coach/insight", { json: body });
    expect(res.status).toBe(502);
    expect(await res.json()).toEqual({ error: "ai_unavailable" });
  });
});
