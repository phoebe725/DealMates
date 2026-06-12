-- Owner self-tagging: a boolean flag so the founder's own browsers can mark their
-- events and be filtered out of "real visitor" counts. The web client sets this
-- from a localStorage flag toggled by visiting ?owner=1 (cleared with ?owner=0).
-- Combined with excluding your stable WiFi IPs, this strips most of your own test
-- traffic — though incognito windows won't carry the flag (they keep no
-- localStorage), so those still rely on IP exclusion.
alter table public.analytics_events add column if not exists is_owner boolean default false;

create index if not exists idx_analytics_events_is_owner on public.analytics_events (is_owner);
