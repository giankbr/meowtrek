import { today, type Plan } from "../config.js";
import { prisma } from "../db.js";

export type LimitKind = "chat" | "insight" | "quests" | "meal";

export const DAILY_LIMITS: Record<LimitKind, Record<Plan, number>> = {
  chat: { free: 5, plus: 200 },
  insight: { free: 3, plus: 30 },
  quests: { free: 3, plus: 30 },
  meal: { free: 1, plus: 20 },
};

const id = (kind: LimitKind, device: string) => `${kind}:${device}:${today()}`;

export async function remaining(kind: LimitKind, device: string, plan: Plan) {
  const rec = await prisma.rateLimit.findUnique({ where: { id: id(kind, device) } });
  return Math.max(0, DAILY_LIMITS[kind][plan] - (rec?.count ?? 0));
}

export async function consume(kind: LimitKind, device: string, plan: Plan) {
  const day = today();
  const rec = await prisma.rateLimit.upsert({
    where: { id: id(kind, device) },
    create: { id: id(kind, device), day, count: 1 },
    update: { count: { increment: 1 } },
  });
  return Math.max(0, DAILY_LIMITS[kind][plan] - rec.count);
}
