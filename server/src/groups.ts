import { type Context, Hono } from "hono";
import { z } from "zod";
import type { AppEnv, Env } from "./env";

// Backend-synced group step challenges: a group is a short code, each member a KV row with their
// week's steps. The leaderboard is shared across devices (unlike the local pal-card board).
export const groups = new Hono<AppEnv>();

const MEMBER_TTL = 30 * 24 * 3600;
const GROUP_TTL = 60 * 24 * 3600;
const MAX_MEMBERS = 50;
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // no ambiguous 0/O/1/I/L

const Member = z.object({
  name: z.string().trim().min(1).max(24),
  fur: z.string().regex(/^[a-z_]{1,24}$/).default("fur_ginger"),
  steps: z.number().int().min(0).max(100_000_000),
  week: z.string().regex(/^\d{4}-W\d{1,2}$/),
});
const CreateBody = z.object({ name: z.string().trim().min(1).max(40), goal: z.number().int().min(0).max(100_000_000).default(0), member: Member });
const JoinBody = z.object({ code: z.string().length(6), member: Member });

type GroupMeta = { name: string; goal: number; createdAt: string };
type StoredMember = z.infer<typeof Member> & { at: string };

const groupKey = (code: string) => `grp:${code}`;
const memberKey = (code: string, device: string) => `grp:${code}:m:${device}`;

function device(c: { req: { header: (k: string) => string | undefined } }): string | null {
  const d = c.req.header("X-Meowtrek-Device");
  return d && /^[0-9A-Fa-f-]{8,64}$/.test(d) ? d : null;
}

function newCode(): string {
  let s = "";
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  for (const b of bytes) s += CODE_ALPHABET[b % CODE_ALPHABET.length];
  return s;
}

async function leaderboard(env: Env, code: string) {
  const { keys } = await env.KV.list({ prefix: `grp:${code}:m:` });
  const rows = await Promise.all(
    keys.slice(0, MAX_MEMBERS).map(async (k) => {
      const m = await env.KV.get<StoredMember>(k.name, "json");
      return m ? { name: m.name, fur: m.fur, steps: m.steps, week: m.week } : null;
    }),
  );
  return rows.filter((r): r is NonNullable<typeof r> => r !== null).sort((a, b) => b.steps - a.steps);
}

async function putMember(env: Env, code: string, dev: string, m: z.infer<typeof Member>) {
  const stored: StoredMember = { ...m, at: new Date().toISOString() };
  await env.KV.put(memberKey(code, dev), JSON.stringify(stored), { expirationTtl: MEMBER_TTL });
}

groups.post("/create", async (c) => {
  const dev = device(c);
  if (!dev) return c.json({ error: "no_device" }, 400);
  const parsed = CreateBody.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);

  let code = "";
  for (let i = 0; i < 5; i++) {
    const candidate = newCode();
    if (!(await c.env.KV.get(groupKey(candidate)))) { code = candidate; break; }
  }
  if (!code) return c.json({ error: "try_again" }, 503);

  const meta: GroupMeta = { name: parsed.data.name, goal: parsed.data.goal, createdAt: new Date().toISOString() };
  await c.env.KV.put(groupKey(code), JSON.stringify(meta), { expirationTtl: GROUP_TTL });
  await putMember(c.env, code, dev, parsed.data.member);
  return c.json({ code, ...meta, members: await leaderboard(c.env, code) });
});

async function handleJoinOrSync(c: Context<AppEnv>) {
  const dev = device(c);
  if (!dev) return c.json({ error: "no_device" }, 400);
  const parsed = JoinBody.safeParse(await c.req.json().catch(() => undefined));
  if (!parsed.success) return c.json({ error: "invalid_request" }, 400);
  const code = parsed.data.code.toUpperCase();
  const meta = await c.env.KV.get<GroupMeta>(groupKey(code), "json");
  if (!meta) return c.json({ error: "no_group" }, 404);
  await putMember(c.env, code, dev, parsed.data.member);
  await c.env.KV.put(groupKey(code), JSON.stringify(meta), { expirationTtl: GROUP_TTL }); // keep the group alive while active
  return c.json({ code, ...meta, members: await leaderboard(c.env, code) });
}

groups.post("/join", (c) => handleJoinOrSync(c));
groups.post("/sync", (c) => handleJoinOrSync(c));

groups.get("/:code", async (c) => {
  const code = c.req.param("code").toUpperCase();
  const meta = await c.env.KV.get<GroupMeta>(groupKey(code), "json");
  if (!meta) return c.json({ error: "no_group" }, 404);
  return c.json({ code, ...meta, members: await leaderboard(c.env, code) });
});

groups.post("/leave", async (c) => {
  const dev = device(c);
  if (!dev) return c.json({ error: "no_device" }, 400);
  const code = z.string().length(6).safeParse((await c.req.json().catch(() => ({})) as { code?: string }).code?.toUpperCase());
  if (!code.success) return c.json({ error: "invalid_request" }, 400);
  await c.env.KV.delete(memberKey(code.data, dev));
  return c.json({ ok: true });
});
