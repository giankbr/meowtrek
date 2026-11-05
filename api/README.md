# Meowtrek API (Node + Express + Prisma + MySQL)

A conventional REST backend, an alternative to the Cloudflare Worker in `../server`.
Same endpoints, but runs on any Node host with a MySQL database.

## Stack
- Express + TypeScript (run with `tsx`)
- Prisma ORM → MySQL
- Anthropic SDK (AI coach), `@apple/app-store-server-library` (Plus verify + notifications)

## Endpoints (`/v1`)
| Route | Purpose |
|---|---|
| `GET /health` | healthcheck |
| `POST /coach/{chat,insight,quests,meal}` | AI cat coach (needs `ANTHROPIC_API_KEY`) |
| `POST /groups/{create,join,sync,leave}`, `GET /groups/:code` | group step challenges |
| `POST /push/{register,unregister}` | APNs device tokens |
| `POST /appstore/notifications` | App Store Server Notifications V2 webhook |
| `GET/DELETE /garmin/*`, `POST /garmin/webhook` | Garmin Health API link + sync |
| `POST /telemetry/{events,diagnostics}`, `GET /telemetry/summary` | anonymous telemetry |

Requests identify the install with the `X-Meowtrek-Device` header (the app's `profileID`);
Plus is proven with a signed StoreKit transaction in `X-Meowtrek-Transaction`.

## Run locally
```bash
cp .env.example .env            # fill ANTHROPIC_API_KEY etc. as needed
docker compose up -d            # MySQL on localhost:3307
npm install
npm run db:push                 # create tables
npm run dev                     # http://localhost:8090
```

## Point the app at it
Set `MeowtrekAPIBase` in the app's `Info.plist` to `https://<your-host>/v1`
(for on-device testing over LAN use `http://<mac-ip>:8090/v1` + an ATS exception).

## Deploy
Any Node host (Railway, Render, Fly, a VPS). Set the env vars, run `npm run db:push`
(or `prisma migrate deploy`), then `npm start`. Put it behind HTTPS.
