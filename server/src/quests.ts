import type { Context, RawQuest } from "./schemas";

export interface Quest {
  title: string;
  detail: string;
  kind: "steps" | "before" | "after" | "activeHours";
  target: number;
  hour?: number;
  reward: number;
}

const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, Math.round(Number.isFinite(n) ? n : lo)));
const inRange = (n: number, r: readonly [number, number]) => clamp(n, r[0], r[1]);
const round100 = (n: number) => Math.round(n / 100) * 100;
const text = (s: string, max: number, fallback: string) => s.replace(/\s+/g, " ").trim().slice(0, max) || fallback;

const RANGES = {
  steps: { target: [500, 30_000] },
  before: { target: [300, 15_000], hour: [6, 21] },
  after: { target: [300, 15_000], hour: [12, 22] },
  activeHours: { target: [1, 12] },
} as const;

export function clampQuest(raw: RawQuest, localHour?: number): Quest {
  const q = { ...raw };
  if (q.kind === "before" && localHour !== undefined && (q.hour ?? 0) <= localHour) {
    if (localHour >= RANGES.before.hour[1]) q.kind = "steps";
    else q.hour = localHour + 2;
  }
  const r = RANGES[q.kind];
  const target = q.kind === "activeHours" ? inRange(q.target, r.target) : round100(inRange(q.target, r.target));
  const out: Quest = {
    title: text(q.title, 40, "Daily quest"),
    detail: text(q.detail, 120, ""),
    kind: q.kind,
    target,
    reward: clamp(q.reward, 10, 80),
  };
  if ("hour" in r) out.hour = inRange(q.hour ?? r.hour[0], r.hour);
  return out;
}

export function defaultQuests(ctx: Context, localHour?: number): Quest[] {
  const goal = round100(clamp(ctx.goal, 500, 30_000));
  const late = localHour !== undefined && localHour >= 9;
  return [
    { title: "Goal getter", detail: `Walk ${goal} steps today`, kind: "steps", target: goal, reward: 50 },
    late
      ? { title: "Evening stroll", detail: "1500 steps after 18:00", kind: "after", target: 1500, hour: 18, reward: 30 }
      : { title: "Early paws", detail: "1000 steps before 9:00", kind: "before", target: 1000, hour: 9, reward: 30 },
    { title: "Keep moving", detail: "5 hours with 250+ steps", kind: "activeHours", target: 5, reward: 40 },
  ];
}

export function finalizeQuests(raw: RawQuest[], ctx: Context, localHour?: number): Quest[] {
  const quests = raw.slice(0, 3).map((q) => clampQuest(q, localHour));
  for (const d of defaultQuests(ctx, localHour)) {
    if (quests.length >= 3) break;
    if (!quests.some((q) => q.kind === d.kind)) quests.push(d);
  }
  return quests;
}
