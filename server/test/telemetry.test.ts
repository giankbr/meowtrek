import { describe, expect, it } from "vitest";
import { makeEnv, setup } from "./helpers";

const crash = JSON.stringify({ crashDiagnostics: [{ callStackTree: {} }], hangDiagnostics: [] });

describe("telemetry", () => {
  it("aggregates event counts per day without ids", async () => {
    const env = makeEnv();
    const { call } = setup(env);
    const body = { appVersion: "1.0", events: [{ name: "app_open" }, { name: "trek_finished_run", count: 2 }, { name: "app_open" }] };
    expect((await call("/v1/telemetry/events", { json: body }, {})).status).toBe(200);
    const keys = [...(env.KV as unknown as { data: Map<string, unknown> }).data.keys()];
    expect(keys.some((k) => k.endsWith(":app_open"))).toBe(true);
    expect(keys.every((k) => !k.includes("6f1c8a2e"))).toBe(true);
    const res = await call("/v1/telemetry/summary?days=1", {}, { Authorization: "Bearer secret" });
    expect(res.status).toBe(403);
    const ok = await setup({ ...env, ADMIN_TOKEN: "secret" }).call("/v1/telemetry/summary?days=1", {}, { Authorization: "Bearer secret" });
    const summary = (await ok.json()) as { days: { events: Record<string, number> }[] };
    expect(summary.days[0].events).toEqual({ app_open: 2, trek_finished_run: 2 });
  });

  it("rejects bad event names", async () => {
    const res = await setup(makeEnv()).call("/v1/telemetry/events", { json: { appVersion: "1.0", events: [{ name: "Bad Name!" }] } }, {});
    expect(res.status).toBe(400);
  });

  it("stores diagnostics with their kinds", async () => {
    const env = makeEnv({ ADMIN_TOKEN: "t" });
    const { call } = setup(env);
    const res = await call("/v1/telemetry/diagnostics", { json: { appVersion: "1.0", osVersion: "iOS 26.4", model: "iPhone17,1", payload: crash } }, {});
    expect(res.status).toBe(200);
    const summary = (await (await call("/v1/telemetry/summary", {}, { Authorization: "Bearer t" })).json()) as { diagnostics: { kinds: string[] }[] };
    expect(summary.diagnostics[0].kinds).toEqual(["crashDiagnostics"]);
  });
});
