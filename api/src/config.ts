import "dotenv/config";

export const cfg = {
  port: Number(process.env.PORT ?? 8080),
  anthropicKey: process.env.ANTHROPIC_API_KEY,
  claudeModel: process.env.CLAUDE_MODEL ?? "claude-opus-5-5",
  appleBundleId: process.env.APPLE_BUNDLE_ID ?? "id.gian.meowtrek",
  appleEnv: process.env.APPLE_ENVIRONMENT ?? "Sandbox",
  appleAppId: process.env.APPLE_APP_ID,
  allowUnverifiedPlus: process.env.ALLOW_UNVERIFIED_PLUS === "true",
  apnsKey: process.env.APNS_KEY,
  apnsKeyId: process.env.APNS_KEY_ID,
  apnsTeamId: process.env.APNS_TEAM_ID,
  apnsEnv: process.env.APNS_ENVIRONMENT,
  apnsTopic: process.env.APNS_TOPIC,
  garminKey: process.env.GARMIN_CONSUMER_KEY,
  garminSecret: process.env.GARMIN_CONSUMER_SECRET,
  garminWebhookSecret: process.env.GARMIN_WEBHOOK_SECRET,
  adminToken: process.env.ADMIN_TOKEN,
};

export type Plan = "free" | "plus";

export const today = (now = new Date()) => now.toISOString().slice(0, 10);
