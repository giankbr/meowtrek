# Meowtrek API

Small backend for the Meowtrek iOS app: Cloudflare Workers + Hono + TypeScript, Workers KV for state, Claude for the cat coach, StoreKit 2 for Plus, Garmin Health API for steps.

```
src/
  index.ts      app wiring, /v1/health, JSON 404/500
  coach.ts      /v1/coach/* (device auth, plan, daily limits)
  claude.ts     prompts + Anthropic SDK calls
  quests.ts     quest clamping / defaults
  plus.ts       StoreKit 2 JWS verification (Plus)
  limits.ts     KV daily counters
  garmin.ts     /v1/garmin/* (OAuth 2.0 PKCE, webhook, steps)
  schemas.ts    zod request/response schemas
  appleRoot.ts  Apple Root CA - G3
test/           vitest (Anthropic client and fetch are mocked)
```

## Setup

```sh
cd server
npm i
npx wrangler login
npx wrangler kv namespace create KV          # paste the id into wrangler.toml [[kv_namespaces]]
npx wrangler secret put ANTHROPIC_API_KEY
```

Optional, once Garmin approves the developer account:

```sh
npx wrangler secret put GARMIN_CONSUMER_KEY
npx wrangler secret put GARMIN_CONSUMER_SECRET
npx wrangler secret put GARMIN_WEBHOOK_SECRET   # random string, see Garmin below
```

## Local dev

```sh
printf 'ANTHROPIC_API_KEY=sk-ant-...\nALLOW_UNVERIFIED_PLUS=true\n' > .dev.vars   # gitignored
npm run dev                                     # http://localhost:8787, local KV in .wrangler/
npm test                                        # vitest
npx tsc --noEmit
```

Point the simulator at `http://localhost:8787`; on a device use your Mac's LAN IP or `wrangler dev --remote`.

## Deploy

```sh
npm run deploy        # wrangler deploy
```

For the App Store build set `APPLE_ENVIRONMENT = "Production"` and `APPLE_APP_ID` in `wrangler.toml`, and make sure `ALLOW_UNVERIFIED_PLUS` is `"false"`.

## Environment

| Name | Kind | Default | Purpose |
|---|---|---|---|
| `KV` | KV binding | - | Rate limits, Plus cache, Garmin links/tokens/steps |
| `ANTHROPIC_API_KEY` | secret | - | Claude API key. Missing -> coach endpoints return 503 `ai_not_configured` |
| `CLAUDE_MODEL` | var | `claude-opus-5-5` | Model id for all coach calls |
| `APPLE_BUNDLE_ID` | var | `id.gian.meowtrek` | Must match the transaction's `bundleId` |
| `APPLE_ENVIRONMENT` | var | `Sandbox` | `Sandbox` (TestFlight/dev) or `Production`. Production also accepts Sandbox-signed transactions (App Review buys in Sandbox) |
| `APPLE_APP_ID` | var | - | Numeric App Store app id; required when `APPLE_ENVIRONMENT=Production` |
| `ALLOW_UNVERIFIED_PLUS` | var | `false` | **Dev only.** `true` decodes the JWS without checking Apple's signature |
| `GARMIN_CONSUMER_KEY` | secret | - | Garmin OAuth2 client id. Missing -> all `/v1/garmin/*` return 503 |
| `GARMIN_CONSUMER_SECRET` | secret | - | Garmin OAuth2 client secret |
| `GARMIN_WEBHOOK_SECRET` | secret | - | If set, webhook must be called at `/v1/garmin/webhook/<secret>` |

### StoreKit and Xcode

Transactions made with a local `.storekit` configuration file in Xcode are signed by Xcode, not by Apple, so `SignedDataVerifier` cannot verify them (their `environment` is `Xcode`). For that workflow put `ALLOW_UNVERIFIED_PLUS=true` in `.dev.vars`. Sandbox (TestFlight / sandbox Apple ID) transactions verify normally against Apple Root CA - G3. Online revocation (OCSP) checks are off; revoked purchases are caught through `revocationDate` once the app sends a refreshed transaction.

## API

All bodies are JSON. Errors are always `{ "error": "<code>" }` (plus extra fields where noted).

### Common headers (coach)

| Header | Required | Notes |
|---|---|---|
| `X-Meowtrek-Device` | yes | Random UUID per install. Missing/invalid -> `401 {"error":"device_required"}` |
| `X-Meowtrek-Transaction` | no | StoreKit 2 `Transaction.jwsRepresentation` for `id.gian.meowtrek.plus.monthly` / `.yearly`. Invalid/expired -> treated as free (no error) |

Response headers on coach endpoints: `X-Plan: free|plus`, `X-Remaining: <n>` (calls left today for that endpoint, after this one).

Daily limits per device (UTC day), counted only on success:

| Endpoint | Free | Plus |
|---|---|---|
| chat | 5 | 200 |
| insight | 3 | 30 |
| quests | 3 | 30 |

Over the limit: `429 {"error":"limit","remaining":0}` with `X-Remaining: 0`.

Coach error codes: `400 invalid_request` (with `issues: [{path, message}]`), `401 device_required`, `429 limit`, `502 ai_unavailable` (model refused / unusable output / non-retryable upstream error), `503 ai_busy` (Anthropic 429/5xx), `503 ai_not_configured`.

`context` object (shared):

```json
{
  "petName": "Mochi",          // 1-40 chars
  "mood": "happy",             // <=40 chars, optional (default "happy")
  "todaySteps": 3200,          // int 0-200000
  "goal": 8000,                // int 100-100000
  "streak": 4,                 // int 0-10000
  "weekSteps": [5000, 6000, 7000, 8000, 9000, 4000, 3200],  // exactly 7 ints, oldest first
  "level": 3,                  // int 0-10000
  "locale": "id-ID"            // 2-35 chars; "id*" -> Indonesian replies
}
```

#### `POST /v1/coach/chat`

```json
{ "messages": [ { "role": "user", "content": "Halo Mochi, aku capek" } ], "context": { ... } }
```

`messages`: 1-40 items, `role` `user|assistant`, `content` 1-2000 chars, last must be `user`. Only the last 20 are sent to the model.

```json
200 { "reply": "Purr... istirahat sebentar boleh kok! Nanti sore kita jalan 10 menit ya?" }
```

A model refusal still returns 200 with a short in-character decline.

#### `POST /v1/coach/insight`

```json
{ "context": { ... }, "last28Days": [ 4000, 5200, ... ] }   // exactly 28 ints, oldest first
```

```json
200 {
  "headline": "Langkahmu makin mantap!",
  "summary": "Rata-rata minggu ini 6.900 langkah, naik 12% dari minggu lalu...",
  "tips": ["...", "...", "..."],      // always 3
  "suggestedGoal": 7500                // int 1000-30000, multiple of 100
}
```

#### `POST /v1/coach/quests`

```json
{ "context": { ... }, "localHour": 14 }   // localHour optional, 0-23
```

```json
200 [
  { "title": "Jalan santai", "detail": "Jalan 8000 langkah hari ini", "kind": "steps", "target": 8000, "reward": 50 },
  { "title": "Sore ceria", "detail": "1500 langkah setelah jam 17", "kind": "after", "target": 1500, "hour": 17, "reward": 30 },
  { "title": "Terus bergerak", "detail": "5 jam dengan 250+ langkah", "kind": "activeHours", "target": 5, "reward": 40 }
]
```

Always exactly 3. Server-side clamping:

| kind | target | hour |
|---|---|---|
| `steps` | 500-30000 steps, rounded to 100 | absent |
| `before` | 300-15000 steps, rounded to 100 | 6-21 (moved after `localHour` if already passed; becomes `steps` after 21:00) |
| `after` | 300-15000 steps, rounded to 100 | 12-22 |
| `activeHours` | 1-12 hours (hours with 250+ steps) | absent |

`reward` 10-80 coins, `title` <=40 chars, `detail` <=120 chars. Missing quests are filled from built-in defaults.

### Garmin

Every `/v1/garmin/*` route returns `503 {"error":"garmin_not_configured"}` until `GARMIN_CONSUMER_KEY` and `GARMIN_CONSUMER_SECRET` are set.

Garmin's Connect Developer Program uses **OAuth 2.0 with PKCE** (it replaced OAuth 1.0a). Spec: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE.pdf (authorize `https://connect.garmin.com/oauth2Confirm`, token `https://connectapi.garmin.com/di-oauth2-service/oauth/token`, user id `GET https://apis.garmin.com/wellness-api/rest/user/id`, disconnect `DELETE .../user/registration`). Access tokens last ~24h (`expires_in` 86400), refresh tokens ~90 days; the server refreshes 10 minutes early.

Flow from the app:

1. `GET /v1/garmin/authorize` with `X-Meowtrek-Device` -> `200 {"url": "https://connect.garmin.com/oauth2Confirm?..."}` (state valid 10 min).
2. Open `url` in `ASWebAuthenticationSession` with callback scheme `meowtrek`.
3. Garmin redirects to `/v1/garmin/callback`, which redirects to `meowtrek://garmin?status=<status>`:
   `linked` | `denied` (user declined) | `expired` (unknown/old state) | `error` (token or user-id call failed).

| Route | Auth | Response |
|---|---|---|
| `GET /v1/garmin/authorize` | device | `200 {"url"}` / `401 device_required` |
| `GET /v1/garmin/callback?code&state` | Garmin redirect | `302` to `meowtrek://garmin?status=...` |
| `GET /v1/garmin/status` | device | `200 {"linked": true}` |
| `GET /v1/garmin/steps?days=30` | device | `200 {"days": [{"date":"2026-11-04","steps":4321}, ...]}` ascending, only days Garmin has sent; `days` 1-90 (default 30, UTC dates); `404 garmin_not_linked` |
| `DELETE /v1/garmin/link` | device | `200 {"ok": true}`; also calls Garmin's deregistration (required by Garmin when the app offers its own disconnect) |
| `POST /v1/garmin/webhook[/<secret>]` | Garmin | `200 {"ok": true}`; `403 forbidden` on wrong secret; `400 invalid_request` |

Garmin portal configuration:

- Redirect URL: `https://<worker-host>/v1/garmin/callback`
- Push or Ping endpoint for **Dailies** and **Deregistrations**: `https://<worker-host>/v1/garmin/webhook/<GARMIN_WEBHOOK_SECRET>`

Webhook handling: `{"dailies":[{userId, calendarDate, steps, ...}]}` (push) is stored directly; `{"dailies":[{userId, callbackURL}]}` (ping) is pulled with the user's bearer token, only from `https://apis.garmin.com`; `{"deregistrations":[{userId}]}` unlinks. Work runs after the 200 via `waitUntil`. Steps live in KV for 120 days, keyed by Garmin user and date; later summaries for the same day overwrite earlier ones. One Garmin account can be linked from up to 5 devices.

### Health

`GET /v1/health` -> `200 {"ok": true}`

## Model

`CLAUDE_MODEL` defaults to `claude-opus-5-5` (Claude Opus 5.5, the current default per Anthropic's guidance), called with `output_config.effort: "low"`: chat-style work keeps its quality at low effort and it skips most thinking, which keeps latency and token spend down. Insight and quests use structured outputs (`messages.parse` + zod schema) and are then range-checked in code. Requests opt into server-side refusal fallback (`fallbacks: "default"`, beta `server-side-fallback-2026-07-01`).

## Costs

Rough per-call estimate with the default model ($4 / $20 per million input/output tokens):

| Call | Input | Output | Cost |
|---|---|---|---|
| chat (short history) | ~1.0k tok | ~0.2k tok | ~$0.008 |
| insight | ~1.0k tok | ~0.4k tok | ~$0.012 |
| quests | ~0.9k tok | ~0.4k tok | ~$0.012 |

So a Plus user chatting 10x/day plus one insight and one quest set costs ~$0.10/day (~$3/month); a user who hits the 200-chat cap every day costs ~$1.60/day. Free users are capped at about $0.10/day.

For a subscription consumer app, consider `CLAUDE_MODEL = "claude-haiku-5-5"` ($0.10 / $0.50 per million tokens, about 40x cheaper: ~$0.0002 per chat). Check reply quality on real prompts first. Haiku 5.5 has no server-side refusal fallback; refusals are still handled (in-character reply / 502). Changing the model is just a var change plus redeploy.

Cloudflare: Workers Paid ($5/month) covers 10M requests; KV writes (1M/month included, then $5/M) are the main per-request cost (one counter write per successful coach call, one per Garmin daily).

## Notes / limits

- KV has no atomic increment; parallel bursts from one device can exceed the daily limit by a few calls.
- Rate-limit days are UTC.
- A Plus transaction JWS is not bound to a device; anyone holding a valid JWS gets Plus limits.
- Garmin push/ping payload field names (`dailies`, `calendarDate`, `steps`, `callbackURL`, `deregistrations`) come from the Health API spec as publicly described; confirm against the portal docs once the developer account is approved.

### `POST /v1/coach/meal`

Body: `{ context, image: base64 (JPEG/PNG/WebP, ≤ ~1.5 MB), mediaType?: "image/jpeg" }` → `200 { isFood, reaction, tags: string[], balance: 1-5 }`.
Tags come from `veggies, fruit, protein, grains, dairy, sweets, fried, drink, homemade`. No calorie counting by design. Daily limit: free 1, Plus 20.

### Telemetry (anonymous)

- `POST /v1/telemetry/events` — `{ appVersion, events: [{ name: "trek_finished_run", count?: 1 }] }` (≤ 50 events, names `[a-z][a-z0-9_]`). Stored only as per-day counters `tm:ev:<date>:<name>`; no device or user id is kept.
- `POST /v1/telemetry/diagnostics` — `{ appVersion, osVersion, model, payload }` where `payload` is a MetricKit `MXDiagnosticPayload` JSON (crashes, hangs). Kept 30 days.
- `GET /v1/telemetry/summary?days=7` — `Authorization: Bearer $ADMIN_TOKEN` (set with `wrangler secret put ADMIN_TOKEN`). Returns daily event counts, app versions and recent diagnostics.
