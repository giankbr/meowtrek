import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db.js";

export const groups = Router();

const MAX_MEMBERS = 50;
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

const Member = z.object({
  name: z.string().trim().min(1).max(24),
  fur: z.string().regex(/^[a-z_]{1,24}$/).default("fur_ginger"),
  steps: z.number().int().min(0).max(100_000_000),
  week: z.string().regex(/^\d{4}-W\d{1,2}$/),
});
const CreateBody = z.object({ name: z.string().trim().min(1).max(40), goal: z.number().int().min(0).max(100_000_000).default(0), member: Member });
const JoinBody = z.object({ code: z.string().length(6), member: Member });

function device(req: { header(name: string): string | undefined }): string | null {
  const d = req.header("X-Meowtrek-Device");
  return d && /^[0-9A-Fa-f-]{8,64}$/.test(d) ? d : null;
}

function newCode(): string {
  let s = "";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  for (const b of bytes) s += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return s;
}

async function leaderboard(code: string) {
  const rows = await prisma.groupMember.findMany({
    where: { groupCode: code },
    orderBy: { steps: "desc" },
    take: MAX_MEMBERS,
    select: { name: true, fur: true, steps: true, week: true },
  });
  return rows;
}

async function present(code: string) {
  const g = await prisma.group.findUnique({ where: { code } });
  if (!g) return null;
  return { code: g.code, name: g.name, goal: g.goal, createdAt: g.createdAt, members: await leaderboard(code) };
}

async function upsertMember(code: string, dev: string, m: z.infer<typeof Member>) {
  await prisma.groupMember.upsert({
    where: { groupCode_device: { groupCode: code, device: dev } },
    create: { groupCode: code, device: dev, name: m.name, fur: m.fur, steps: m.steps, week: m.week },
    update: { name: m.name, fur: m.fur, steps: m.steps, week: m.week },
  });
}

groups.post("/create", async (req, res) => {
  const dev = device(req);
  if (!dev) return res.status(400).json({ error: "no_device" });
  const parsed = CreateBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });

  let code = "";
  for (let i = 0; i < 5; i++) {
    const candidate = newCode();
    if (!(await prisma.group.findUnique({ where: { code: candidate } }))) { code = candidate; break; }
  }
  if (!code) return res.status(503).json({ error: "try_again" });

  await prisma.group.create({ data: { code, name: parsed.data.name, goal: parsed.data.goal } });
  await upsertMember(code, dev, parsed.data.member);
  res.json(await present(code));
});

async function joinOrSync(req: any, res: any) {
  const dev = device(req);
  if (!dev) return res.status(400).json({ error: "no_device" });
  const parsed = JoinBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
  const code = parsed.data.code.toUpperCase();
  if (!(await prisma.group.findUnique({ where: { code } }))) return res.status(404).json({ error: "no_group" });
  await upsertMember(code, dev, parsed.data.member);
  res.json(await present(code));
}

groups.post("/join", joinOrSync);
groups.post("/sync", joinOrSync);

groups.get("/:code", async (req, res) => {
  const out = await present(req.params.code.toUpperCase());
  if (!out) return res.status(404).json({ error: "no_group" });
  res.json(out);
});

groups.post("/leave", async (req, res) => {
  const dev = device(req);
  if (!dev) return res.status(400).json({ error: "no_device" });
  const code = z.string().length(6).safeParse(String(req.body?.code ?? "").toUpperCase());
  if (!code.success) return res.status(400).json({ error: "invalid_request" });
  await prisma.groupMember.deleteMany({ where: { groupCode: code.data, device: dev } });
  res.json({ ok: true });
});
