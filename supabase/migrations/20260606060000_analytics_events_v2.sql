-- Evolve analytics_events: add session_id + structured fk-ish id columns.
-- Self-sufficient — creates the table fresh if the v1 migration never ran, and
-- alters it in place if it did.
create table if not exists public.analytics_events (
    id            uuid primary key default gen_random_uuid(),
    event_name    text not null,
    guest_id      text not null,
    session_id    text,
    page_path     text,
    restaurant_id text,
    offer_id      text,
    plan_id       text,
    metadata      jsonb,
    created_at    timestamptz not null default now()
);

alter table public.analytics_events add column if not exists session_id    text;
alter table public.analytics_events add column if not exists restaurant_id text;
alter table public.analytics_events add column if not exists offer_id      text;
alter table public.analytics_events add column if not exists plan_id       text;

-- Carry over data from the v1 `deal_id` column (deal_click → offer_id), then drop it.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'analytics_events' and column_name = 'deal_id'
  ) then
    update public.analytics_events set offer_id = deal_id where offer_id is null and deal_id is not null;
    alter table public.analytics_events drop column deal_id;
  end if;
end $$;

create index if not exists idx_analytics_events_created on public.analytics_events (created_at desc);
create index if not exists idx_analytics_events_name    on public.analytics_events (event_name, created_at desc);
create index if not exists idx_analytics_events_guest   on public.analytics_events (guest_id);
create index if not exists idx_analytics_events_session on public.analytics_events (session_id);

alter table public.analytics_events enable row level security;
-- Anonymous clients may only insert events; they cannot read them back.
drop policy if exists "Insert analytics_events" on public.analytics_events;
create policy "Insert analytics_events"
    on public.analytics_events for insert with check (true);
