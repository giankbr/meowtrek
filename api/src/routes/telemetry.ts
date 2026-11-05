import { Router } from "express";
import { z } from "zod";
import { cfg, today } from "../config.js";
import { prisma } from "../db.js";

export const telemetry = Router();

const EventName = z.string().regex(/^[a-z][a-z0-9_]{1,39}$/);
const EventsBody = z.object({
  appVersion: z.string().max(20),
  events: z.array(z.object({ name: EventName, count: z.number().int().min(1).max(500).default(1) })).min(1).max(50),
});
const DiagnosticsBody = z.object({
  appVersion: z.string().max(20),
  osVersion: z.string().max(40),
  model: z.string().max(40),
  payload: z.string().min(2).max(250_000),
});

async function bump(id: string, date: string, name: string, by: number) {
  await prisma.telemetryCounter.upsert({
    where: { id },
    create: { id, date, name, count: by },
    update: { count: { increment: by } },
  });
}

telemetry.post("/events", async (req, res) => {
  const parsed = EventsBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
  const date = today();
  const totals = new Map<string, number>();
  for (const e of parsed.data.events) totals.set(e.name, (totals.get(e.name) ?? 0) + e.count);
  await Promise.all([...totals].map(([name, n]) => bump(`ev:${date}:${name}`, date, name, n)));
  const ver = parsed.data.appVersion.replace(/[^0-9A-Za-z.]/g, "");
  await bump(`ver:${date}:${ver}`, date, ver, 1);
  res.json({ ok: true });
});

telemetry.post("/diagnostics", async (req, res) => {
  const parsed = DiagnosticsBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
  const { payload, ...meta } = parsed.data;
  let kinds: string[] = [];
  try {
    const p = JSON.parse(payload);
    kinds = ["crashDiagnostics", "hangDiagnostics", "cpuExceptionDiagnostics", "diskWriteExceptionDiagnostics"].filter(
      (k) => Array.isArray(p[k]) && p[k].length > 0,
    );
  } catch {
    return res.status(400).json({ error: "invalid_request" });
  }
  await prisma.diagnostic.create({ data: { ...meta, kinds: kinds.join(","), payload } });
  res.json({ ok: true });
});

telemetry.get("/summary", async (req, res) => {
  if (!cfg.adminToken || req.header("Authorization") !== `Bearer ${cfg.adminToken}`) return res.status(403).json({ error: "forbidden" });
  const days = Math.min(90, Math.max(1, Number(req.query.days ?? 7) || 7));
  const since = today(new Date(Date.now() - (days - 1) * 86_400_000));
  const counters = await prisma.telemetryCounter.findMany({ where: { date: { gte: since } } });
  const diagnostics = await prisma.diagnostic.findMany({ orderBy: { createdAt: "desc" }, take: 100 });
  res.json({ counters, diagnostics: diagnostics.map((d) => ({ ...d, payload: undefined })) });
});
