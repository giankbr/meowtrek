import { describe, expect, it } from "vitest";
import { clampQuest, finalizeQuests } from "../src/quests";
import { context, makeEnv, mockClaude, setup } from "./helpers";

const q = (over: object) => ({ title: "Walk", detail: "Go", kind: "steps" as const, target: 5000, hour: null, reward: 30, ...over });

describe("clampQuest", () => {
  it("clamps steps target and reward, drops hour", () => {
    expect(clampQuest(q({ target: 999_999, reward: 5000, hour: 7 }))).toEqual({ title: "Walk", detail: "Go", kind: "steps", target: 30_000, reward: 80 });
    expect(clampQuest(q({ target: 12, reward: -3 }))).toMatchObject({ target: 500, reward: 10 });
  });

  it("rounds step targets to 100", () => {
    expect(clampQuest(q({ target: 4321 })).target).toBe(4300);
  });

  it("before/after get a sane hour", () => {
    expect(clampQuest(q({ kind: "before", target: 50_000, hour: 3 }))).toMatchObject({ target: 15_000, hour: 6 });
    expect(clampQuest(q({ kind: "after", hour: null }))).toMatchObject({ hour: 12 });
    expect(clampQuest(q({ kind: "after", hour: 30 }))).toMatchObject({ hour: 22 });
  });

  it("activeHours target is hours 1..12", () => {
    expect(clampQuest(q({ kind: "activeHours", target: 40 }))).toMatchObject({ target: 12 });
    expect(clampQuest(q({ kind: "activeHours", target: 0 }))).toMatchObject({ target: 1 });
  });

  it("moves a passed 'before' hour forward, or turns it into steps late at night", () => {
    expect(clampQuest(q({ kind: "before", hour: 9 }), 14)).toMatchObject({ kind: "before", hour: 16 });
    const late = clampQuest(q({ kind: "before", hour: 9 }), 22);
    expect(late.kind).toBe("steps");
    expect(late.hour).toBeUndefined();
  });

  it("trims long text", () => {
    const out = clampQuest(q({ title: "x".repeat(100), detail: "y ".repeat(200) }));
    expect(out.title.length).toBe(40);
    expect(out.detail.length).toBeLessThanOrEqual(120);
  });
});

describe("finalizeQuests", () => {
  it("always returns exactly 3", () => {
    expect(finalizeQuests([], context)).toHaveLength(3);
    expect(finalizeQuests([q({}), q({}), q({}), q({}), q({})], context)).toHaveLength(3);
    const one = finalizeQuests([q({ kind: "activeHours", target: 4 })], context);
    expect(one.map((x) => x.kind)).toEqual(["activeHours", "steps", "before"]);
  });
});

describe("POST /v1/coach/quests", () => {
  it("returns clamped quests", async () => {
    const parsed = {
      quests: [
        q({ target: 1_000_000 }),
        q({ kind: "before", target: 2000, hour: 1, reward: 999 }),
        q({ kind: "activeHours", target: 99 }),
      ],
    };
    const res = await setup(makeEnv(), mockClaude({ parsed }).client).call("/v1/coach/quests", { json: { context } });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { target: number; hour?: number; reward: number }[];
    expect(body).toHaveLength(3);
    expect(body[0].target).toBe(30_000);
    expect(body[1]).toMatchObject({ hour: 6, reward: 80 });
    expect(body[2].target).toBe(12);
  });

  it("rejects a bad localHour", async () => {
    const res = await setup(makeEnv()).call("/v1/coach/quests", { json: { context, localHour: 24 } });
    expect(res.status).toBe(400);
  });
});
