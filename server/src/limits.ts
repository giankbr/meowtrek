import { today, type Env, type Plan } from "./env";

export type LimitKind = "chat" | "insight" | "quests" | "meal";

export const DAILY_LIMITS: Record<LimitKind, Record<Plan, number>> = {
  chat: { free: 5, plus: 200 },
  insight: { free: 3, plus: 30 },
  quests: { free: 3, plus: 30 },
  meal: { free: 1, plus: 20 },
};

const key = (kind: LimitKind, device: string) => `rl:${kind}:${device}:${today()}`;

// KV has no atomic increment, so bursts of parallel requests can overshoot by a few; fine for a soft quota.
export async function remaining(env: Env, kind: LimitKind, device: string, plan: Plan) {
  const used = Number((await env.KV.get(key(kind, device))) ?? 0);
  return Math.max(0, DAILY_LIMITS[kind][plan] - used);
}

export async function consume(env: Env, kind: LimitKind, device: string, plan: Plan) {
  const k = key(kind, device);
  const used = Number((await env.KV.get(k)) ?? 0) + 1;
  await env.KV.put(k, String(used), { expirationTtl: 2 * 24 * 3600 });
  return Math.max(0, DAILY_LIMITS[kind][plan] - used);
}
