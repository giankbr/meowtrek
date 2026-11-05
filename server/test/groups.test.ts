import { describe, expect, it } from "vitest";
import { DEVICE, makeEnv, setup } from "./helpers";

const DEVICE2 = "11112222-3333-4444-5555-666677778888";
const member = (name: string, steps: number, fur = "fur_ginger", week = "2026-W45") => ({ name, fur, steps, week });

describe("group challenges", () => {
  it("creates a group, joins from another device, and ranks the leaderboard", async () => {
    const env = makeEnv();
    const s = setup(env);

    const created = await s.call("/v1/groups/create", { json: { name: "Walk Club", goal: 50000, member: member("Gian", 12000) } });
    expect(created.status).toBe(200);
    const g = (await created.json()) as { code: string; name: string; members: { name: string; steps: number }[] };
    expect(g.code).toMatch(/^[A-Z0-9]{6}$/);
    expect(g.name).toBe("Walk Club");
    expect(g.members).toHaveLength(1);

    const joined = await s.call("/v1/groups/join", { json: { code: g.code, member: member("Maya", 30000) } }, { "X-Meowtrek-Device": DEVICE2 });
    expect(joined.status).toBe(200);
    const board = ((await joined.json()) as { members: { name: string; steps: number }[] }).members;
    expect(board.map((m) => m.name)).toEqual(["Maya", "Gian"]); // sorted by steps desc
  });

  it("sync overwrites a member's own steps", async () => {
    const env = makeEnv();
    const s = setup(env);
    const g = (await (await s.call("/v1/groups/create", { json: { name: "C", member: member("Gian", 1000) } })).json()) as { code: string };
    await s.call("/v1/groups/sync", { json: { code: g.code, member: member("Gian", 9999) } });
    const board = ((await (await s.call(`/v1/groups/${g.code}`)).json()) as { members: { steps: number }[] }).members;
    expect(board).toHaveLength(1);
    expect(board[0].steps).toBe(9999);
  });

  it("404s an unknown code and lets a member leave", async () => {
    const env = makeEnv();
    const s = setup(env);
    expect((await s.call("/v1/groups/ZZZZZZ")).status).toBe(404);
    expect((await s.call("/v1/groups/join", { json: { code: "ZZZZZZ", member: member("x", 1) } })).status).toBe(404);

    const g = (await (await s.call("/v1/groups/create", { json: { name: "C", member: member("Gian", 1000) } })).json()) as { code: string };
    await s.call("/v1/groups/leave", { json: { code: g.code } });
    const board = ((await (await s.call(`/v1/groups/${g.code}`)).json()) as { members: unknown[] }).members;
    expect(board).toHaveLength(0);
  });

  it("rejects a request without a device header", async () => {
    const env = makeEnv();
    const s = setup(env);
    const res = await s.call("/v1/groups/create", { json: { name: "C", member: member("Gian", 1000) } }, {});
    expect(res.status).toBe(400);
  });
});
