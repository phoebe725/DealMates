-- Minimal first-party analytics. Anonymous guest events only (guest_id from
-- localStorage). No third-party tooling. Clients INSERT only; reads are done
-- with the service role (SQL editor / dashboard), so there is no SELECT policy.
create table if not exists public.analytics_events (
    id          uuid primary key default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    guest_id    text not null,
    event_name  text not null,            -- 'page_view' | 'deal_click'
    page_path   text,
    deal_id     text,
    metadata    jsonb
);

create index if not exists idx_analytics_events_created
    on public.analytics_events (created_at desc);
create index if not exists idx_analytics_events_name
    on public.analytics_events (event_name, created_at desc);
create index if not exists idx_analytics_events_guest
    on public.analytics_events (guest_id);

alter table public.analytics_events enable row level security;
-- Anonymous clients may only insert events; they cannot read them back.
drop policy if exists "Insert analytics_events" on public.analytics_events;
create policy "Insert analytics_events"
    on public.analytics_events for insert with check (true);
