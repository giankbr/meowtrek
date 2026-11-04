import type Anthropic from "@anthropic-ai/sdk";

export interface Env {
  KV: KVNamespace;
  ANTHROPIC_API_KEY?: string;
  CLAUDE_MODEL: string;
  APPLE_BUNDLE_ID: string;
  APPLE_ENVIRONMENT: string;
  APPLE_APP_ID?: string;
  ALLOW_UNVERIFIED_PLUS?: string;
  GARMIN_CONSUMER_KEY?: string;
  GARMIN_CONSUMER_SECRET?: string;
  GARMIN_WEBHOOK_SECRET?: string;
  ADMIN_TOKEN?: string;
}

export type Plan = "free" | "plus";

export interface Deps {
  anthropic: (env: Env) => Anthropic;
  fetch: typeof fetch;
}

export type AppEnv = {
  Bindings: Env;
  Variables: { device: string; plan: Plan; deps: Deps };
};

export const today = (now = new Date()) => now.toISOString().slice(0, 10);
