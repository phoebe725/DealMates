-- Per-user APNs device tokens. The Edge Function reads these to fan out push notifications.
create table if not exists public.device_tokens (
    user_id text not null,
    token   text not null,
    platform text not null default 'ios',
    notification_preference text not null default 'subscribed',
    created_at timestamptz default now(),
    primary key (user_id, token)
);

create index if not exists idx_device_tokens_user on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "Read own tokens"  on public.device_tokens;
drop policy if exists "Upsert own token" on public.device_tokens;
drop policy if exists "Delete own token" on public.device_tokens;

create policy "Read own tokens"  on public.device_tokens for select using (true);
create policy "Upsert own token" on public.device_tokens for insert with check (true);
create policy "Update own token" on public.device_tokens for update using (true) with check (true);
create policy "Delete own token" on public.device_tokens for delete using (true);

grant select, insert, update, delete on public.device_tokens to anon, authenticated, service_role;
