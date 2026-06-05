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

## Deploy (public link for testers — no TestFlight needed)

It's a static SPA + service worker, so any static host works. **Root directory = `web`.**

**Vercel** (recommended)
1. Import the GitHub repo at vercel.com.
2. Root Directory: `web` · Framework preset: **Vite** · Build: `npm run build` · Output: `dist`.
3. (SPA routing) add `web/vercel.json`:
   ```json
   { "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
   ```
4. Deploy → public HTTPS URL, installable as a PWA on iOS/Android.

**Netlify**
- Base directory `web`, build `npm run build`, publish `web/dist`.
- Add `web/public/_redirects` containing: `/*  /index.html  200`.

**Firebase Hosting**
- `firebase init hosting` → public dir `web/dist`, single-page app: **yes**, then `npm run build && firebase deploy`.

CLI quick path (Vercel): `cd web && npx vercel --prod`.

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
