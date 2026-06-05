# PinTable — Web / PWA

A faithful browser/PWA port of the PinTable iOS app. It talks to the **same
Supabase project** (same schema, auth, realtime, storage) — no separate backend.

Stack: Vite + React + TypeScript + Tailwind + `@supabase/supabase-js` +
TanStack Query + `vite-plugin-pwa`.

## Run locally

```bash
cd web
npm install
npm run dev        # http://localhost:5173
```

It connects to the shared Supabase project by default (keys baked into
`src/lib/supabase.ts`, same publishable key as the iOS app). To point elsewhere,
copy `.env.example` → `.env` and set `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`.

```bash
npm run build      # type-check + production bundle into dist/
npm run preview    # serve the built bundle locally
```

## Deploy — Firebase Hosting (public `*.web.app` link, no custom domain)

`firebase.json` + `.firebaserc` are committed and point at the project
**`pintable-london`** → the app goes live at **https://pintable-london.web.app**.
All deploys are run manually from this `web/` folder.

**One-time setup**
```bash
npm install -g firebase-tools     # or use `npx firebase-tools` below
firebase login                    # opens browser, sign in with the project's Google account
# Create the Firebase project so the domain is pintable-london.web.app:
firebase projects:create pintable-london
```
If `pintable-london` is taken, create any available id and update `default` in
`web/.firebaserc` to match (the domain is always `<projectId>.web.app`). To force
a specific subdomain regardless of project id, instead create a Hosting *site*:
`firebase hosting:sites:create pintable-london` and add a deploy target.

**Deploy (run from `web/`)**
```bash
cd web
npm run build
firebase deploy            # or: firebase deploy --only hosting
```
That uploads `web/dist` and prints the live URL (`https://pintable-london.web.app`).
Re-run `npm run build && firebase deploy` any time to publish updates.

> `npx firebase-tools login` / `npx firebase-tools deploy` work without a global install.
> The SPA rewrite + cache headers are already configured in `firebase.json`.

## Status (phased port)

Done: app shell + bottom tabs, theme/fonts/i18n (EN/简/繁), anonymous→email auth
with confirmation gate, and **Discover** (restaurants + plans, Featured, cuisine
chips incl. AYCE/Buffet, search, deal badges, joined counts) on live data.

Next: Restaurant board · Plan detail (realtime chat, polls, attendance, share) ·
Create table · Join/leave · My Plans · Messages/DMs · full Profile/Settings.

## Documented differences from iOS (web platform)
- **Push notifications:** deferred. In-app realtime updates work; OS push needs
  Web Push (service worker + VAPID) — a planned fast-follow.
- **Add to calendar:** will use an `.ics` / Google Calendar link instead of EventKit.
- **Map / distance:** will use a web map + the browser Geolocation API instead of MapKit.
- **Avatar picker:** `<input type="file">` → same `avatars` storage bucket.
