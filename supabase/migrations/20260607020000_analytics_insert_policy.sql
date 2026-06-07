-- Restore inserts into analytics_events. RLS is on but no working INSERT policy
-- is present, so every client insert (incl. session_start) is rejected with
-- "new row violates row-level security policy". Clients are anonymous or
-- authenticated; both must be able to insert (but never read).
alter table public.analytics_events enable row level security;

drop policy if exists "Insert analytics_events" on public.analytics_events;
create policy "Insert analytics_events"
  on public.analytics_events
  for insert
  to anon, authenticated
  with check (true);

-- Table-level privilege (RLS still gates the rows; this grants the verb).
grant insert on public.analytics_events to anon, authenticated;
