create table if not exists "public"."direct_messages" (
  "id" uuid primary key default gen_random_uuid(),
  "sender_id" text not null,
  "sender_name" text not null,
  "sender_avatar_url" text,
  "recipient_id" text not null,
  "recipient_name" text not null,
  "recipient_avatar_url" text,
  "text" text not null,
  "timestamp" timestamptz not null default now()
);

create index if not exists idx_dm_sender on public.direct_messages (sender_id, timestamp desc);
create index if not exists idx_dm_recipient on public.direct_messages (recipient_id, timestamp desc);
create index if not exists idx_dm_pair on public.direct_messages (sender_id, recipient_id, timestamp);

alter table "public"."direct_messages" enable row level security;

drop policy if exists "Read own DMs" on public.direct_messages;
drop policy if exists "Send DMs" on public.direct_messages;

create policy "Read own DMs"
  on public.direct_messages for select
  using (true);

create policy "Send DMs"
  on public.direct_messages for insert
  with check (true);

grant select, insert on table public.direct_messages to anon, authenticated, service_role;

alter publication supabase_realtime add table public.direct_messages;
