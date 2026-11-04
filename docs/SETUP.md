# Setup guide

Everything in Meowtrek is built; these are the accounts and IDs only you can create. Each step says where the value goes.

## 1. Apple Developer Program ($99/year)

Needed for HealthKit, App Groups, iCloud, in-app purchases and installing on a real iPhone/Watch.

1. Enrol at <https://developer.apple.com/programs/>.
2. In Xcode › Meowtrek target › Signing & Capabilities, pick your **Team** for all three targets (Meowtrek, MeowtrekWidget, MeowtrekWatch). Xcode registers the IDs and capabilities below automatically:
   - Bundle IDs: `id.gian.meowtrek`, `id.gian.meowtrek.widget`, `id.gian.meowtrek.watchkitapp`
   - HealthKit (app + watch)
   - App Group `group.id.gian.meowtrek` (app + widget)
   - iCloud › CloudKit, container `iCloud.id.gian.meowtrek` (app)
3. After the first run with iCloud, open <https://icloud.developer.apple.com>, select the container, and **Deploy Schema Changes** to Production (record type `Backup` is created automatically in Development).

## 2. App Store Connect

1. Agreements, Tax and Banking: accept the **Paid Apps** agreement and add bank/tax details (required for any in-app purchase).
2. Create the app with bundle ID `id.gian.meowtrek`.
3. In-App Purchases (IDs must match exactly):

   | Product ID | Type | Suggested price |
   |---|---|---|
   | `id.gian.meowtrek.plus.monthly` | Auto-renewable, group "Meowtrek Plus" | $3.99 |
   | `id.gian.meowtrek.plus.yearly` | Auto-renewable, same group, 1-week free trial | $29.99 |
   | `id.gian.meowtrek.gems.small` | Consumable (20 gems) | $0.99 |
   | `id.gian.meowtrek.gems.medium` | Consumable (120 gems) | $4.99 |
   | `id.gian.meowtrek.gems.large` | Consumable (300 gems) | $9.99 |

4. URLs: Privacy Policy `https://giankbr.github.io/meowtrek/privacy.html`, Support `https://giankbr.github.io/meowtrek/support.html`.
5. App Privacy questionnaire, matching the privacy policy:
   - Health & Fitness, Location, Photos: **not collected** (stay on device).
   - User Content (chat messages, meal photos): used for App Functionality, **not linked** to identity, not used for tracking.
   - Diagnostics (crash data) and Usage Data (product interaction): App Functionality / Analytics, **not linked**, not tracking.
   - Purchases: handled by Apple.
6. Local testing without App Store Connect: run the **Meowtrek** scheme from Xcode; it uses `Meowtrek.storekit`.

## 3. Server (AI coach, meal photos, Garmin, telemetry)

Full details in [`server/README.md`](../server/README.md).

```bash
cd server
npm i
npx wrangler login
npx wrangler kv namespace create KV        # paste the id into wrangler.toml
npx wrangler secret put ANTHROPIC_API_KEY  # from https://console.anthropic.com
npx wrangler secret put ADMIN_TOKEN        # any long random string, for /v1/telemetry/summary
npx wrangler deploy
```

- Pick the model in `wrangler.toml` › `CLAUDE_MODEL` (`claude-haiku-5-5` is ~40× cheaper than the default Opus for short cat replies).
- Put the deployed URL (e.g. `https://meowtrek-api.<you>.workers.dev`) in `Info.plist` › `MeowtrekAPIBase`.
- For production StoreKit verification set `APPLE_ENVIRONMENT = "Production"` and `APPLE_APP_ID` (the numeric Apple ID from App Store Connect).

## 4. Instagram Stories (Meta App ID)

Instagram only opens its story composer for apps that send a Meta App ID.

1. Go to <https://developers.facebook.com/apps> › Create app › use case "Other" › type "Business" (any name, e.g. Meowtrek).
2. Copy the **App ID** from the app dashboard.
3. Paste it into `Info.plist` › `MeowtrekFacebookAppID`.

Without it, the button falls back to the normal share sheet.

## 5. Fitbit

1. Register at <https://dev.fitbit.com/apps/new>:
   - OAuth 2.0 Application Type: **Client**
   - Redirect URL: `meowtrek://fitbit`
   - Default Access Type: **Read Only**
2. Copy the **OAuth 2.0 Client ID** into `Info.plist` › `MeowtrekFitbitClientID`.

## 6. Garmin

1. Apply to the Garmin Connect Developer Program (Health API) at <https://developer.garmin.com/gc-developer-program/>. Approval is manual and can take weeks.
2. Once approved, set the server secrets:
   ```bash
   npx wrangler secret put GARMIN_CONSUMER_KEY
   npx wrangler secret put GARMIN_CONSUMER_SECRET
   npx wrangler secret put GARMIN_WEBHOOK_SECRET   # random string
   ```
3. In the Garmin developer portal configure:
   - OAuth redirect: `https://<your-worker>/v1/garmin/callback`
   - Push notifications for **Dailies** and **Deregistrations**: `https://<your-worker>/v1/garmin/webhook/<GARMIN_WEBHOOK_SECRET>`
4. Check the webhook payload field names against Garmin's Health API spec (they were taken from third-party docs; see `server/src/garmin.ts`).
