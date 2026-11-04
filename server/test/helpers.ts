import type Anthropic from "@anthropic-ai/sdk";
import { vi } from "vitest";
import type { Env } from "../src/env";
import { createApp } from "../src/index";

export class MemoryKV {
  data = new Map<string, { value: string; metadata?: unknown }>();
  async get(key: string, type?: "json" | "text") {
    const v = this.data.get(key)?.value;
    if (v === undefined) return null;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(key: string, value: string, opts?: { metadata?: unknown }) {
    this.data.set(key, { value, metadata: opts?.metadata });
  }
  async delete(key: string) {
    this.data.delete(key);
  }
  async list({ prefix = "" }: { prefix?: string } = {}) {
    const keys = [...this.data.entries()]
      .filter(([k]) => k.startsWith(prefix))
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, v]) => ({ name, metadata: v.metadata }));
    return { keys, list_complete: true, cursor: "" };
  }
}

export const DEVICE = "6f1c8a2e-1b2c-4d3e-8f90-123456789abc";

export const context = {
  petName: "Mochi",
  mood: "happy",
  todaySteps: 3200,
  goal: 8000,
  streak: 4,
  weekSteps: [5000, 6000, 7000, 8000, 9000, 4000, 3200],
  level: 3,
  locale: "id-ID",
};

export function makeEnv(over: Partial<Env> = {}): Env {
  return {
    KV: new MemoryKV() as unknown as KVNamespace,
    ANTHROPIC_API_KEY: "test-key",
    CLAUDE_MODEL: "claude-opus-5-5",
    APPLE_BUNDLE_ID: "id.gian.meowtrek",
    APPLE_ENVIRONMENT: "Sandbox",
    ...over,
  };
}

export function mockClaude(opts: { text?: string; parsed?: unknown; stop_reason?: string } = {}) {
  const create = vi.fn(async () => ({
    stop_reason: opts.stop_reason ?? "end_turn",
    content: [{ type: "text", text: opts.text ?? "Meow! Ayo jalan!" }],
  }));
  const parse = vi.fn(async () => ({ stop_reason: opts.stop_reason ?? "end_turn", parsed_output: opts.parsed ?? null }));
  const client = { beta: { messages: { create, parse } } } as unknown as Anthropic;
  return { client, create, parse };
}

export function setup(env: Env, client?: Anthropic, fetchImpl?: typeof fetch) {
  const app = createApp({ anthropic: () => client ?? mockClaude().client, ...(fetchImpl ? { fetch: fetchImpl } : {}) });
  const call = (path: string, init: RequestInit & { json?: unknown } = {}, headers: Record<string, string> = { "X-Meowtrek-Device": DEVICE }) => {
    const { json, ...rest } = init;
    return app.request(
      path,
      {
        ...rest,
        method: rest.method ?? (json === undefined ? "GET" : "POST"),
        headers: { "content-type": "application/json", ...headers, ...(rest.headers as Record<string, string>) },
        body: json === undefined ? undefined : JSON.stringify(json),
      },
      env,
    );
  };
  return { app, call };
}

export const fakeJws = (payload: object) =>
  [{ alg: "ES256" }, payload].map((o) => Buffer.from(JSON.stringify(o)).toString("base64url")).join(".") + ".sig";
