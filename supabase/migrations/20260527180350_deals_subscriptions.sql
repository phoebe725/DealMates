-- Restaurant deals (JSONB array of {title, detail} objects).
alter table public.restaurants
    add column if not exists deals jsonb default '[]'::jsonb;

-- Restaurant subscriptions: user_id ↔ restaurant_id with a created_at.
create table if not exists public.restaurant_subscriptions (
    user_id text not null,
    restaurant_id uuid not null,
    created_at timestamptz default now(),
    primary key (user_id, restaurant_id)
);

create index if not exists idx_rs_user on public.restaurant_subscriptions(user_id);
create index if not exists idx_rs_restaurant on public.restaurant_subscriptions(restaurant_id);

alter table public.restaurant_subscriptions enable row level security;

drop policy if exists "Read subscriptions"   on public.restaurant_subscriptions;
drop policy if exists "Insert subscriptions" on public.restaurant_subscriptions;
drop policy if exists "Delete subscriptions" on public.restaurant_subscriptions;

create policy "Read subscriptions"   on public.restaurant_subscriptions for select using (true);
create policy "Insert subscriptions" on public.restaurant_subscriptions for insert with check (true);
create policy "Delete subscriptions" on public.restaurant_subscriptions for delete using (true);

grant select, insert, delete on public.restaurant_subscriptions to anon, authenticated, service_role;

alter publication supabase_realtime add table public.restaurant_subscriptions;
