import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db.js";

export const push = Router();

const RegisterBody = z.object({ token: z.string().regex(/^[0-9a-fA-F]{64}$/) });

function device(req: { header(name: string): string | undefined }): string | null {
  const d = req.header("X-Meowtrek-Device");
  return d && /^[0-9A-Fa-f-]{8,64}$/.test(d) ? d : null;
}

push.post("/register", async (req, res) => {
  const dev = device(req);
  if (!dev) return res.status(400).json({ error: "no_device" });
  const parsed = RegisterBody.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "invalid_request" });
  const token = parsed.data.token.toLowerCase();
  await prisma.pushToken.upsert({
    where: { device: dev.toLowerCase() },
    create: { device: dev.toLowerCase(), token },
    update: { token },
  });
  res.json({ ok: true });
});

push.post("/unregister", async (req, res) => {
  const dev = device(req);
  if (!dev) return res.status(400).json({ error: "no_device" });
  await prisma.pushToken.deleteMany({ where: { device: dev.toLowerCase() } });
  res.json({ ok: true });
});
