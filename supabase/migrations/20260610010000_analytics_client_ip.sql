-- Capture the client IP on every analytics event so we can (a) estimate how many
-- *real* distinct people show up — distinct ip dedupes one person opening many
-- incognito/new browsers, which each look like a brand-new guest_id/Diner — and
-- (b) exclude our own IP to separate genuine strangers from our own testing.
--
-- Done entirely server-side via a column DEFAULT that reads the forwarded client
-- IP from the PostgREST request headers, so NEITHER the web nor iOS client needs
-- a code change — existing inserts that omit `ip` get it filled automatically.
-- Existing rows stay NULL (we never had the IP for them); only events inserted
-- after this migration are populated.
--
-- Privacy note: analytics_events is RLS insert-only — anon/auth clients can never
-- read it back, so the IP is visible only via the service role (dashboard).

alter table public.analytics_events add column if not exists ip inet;

-- x-forwarded-for is "client, proxy1, proxy2…"; the first hop is the real client.
-- current_setting(..., true) is missing-ok (returns NULL off-request), and every
-- step degrades to NULL so a missing/garbage header just yields ip = NULL.
alter table public.analytics_events
  alter column ip set default (
    nullif(
      btrim(split_part(
        current_setting('request.headers', true)::json ->> 'x-forwarded-for',
        ',', 1
      )),
      ''
    )::inet
  );

create index if not exists idx_analytics_events_ip on public.analytics_events (ip);
