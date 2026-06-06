-- Discover/Deals schema extensions.
--
-- Adds the columns the expanded Discover experience needs (featured flag,
-- deal-freshness timestamp, aggregated plan count, and the two contact fields
-- the weekly deal-refresh job reads), plus the pending_deals review queue that
-- the refresh job writes into and the founder admin view approves from.
--
-- All additive + idempotent (IF NOT EXISTS) so it's safe to re-run.

-- 1. Restaurant columns -----------------------------------------------------
alter table public.restaurants
    add column if not exists is_featured            boolean default false,
    add column if not exists last_deals_verified_at timestamptz,
    add column if not exists plan_count             integer default 0,
    add column if not exists instagram_handle       text,
    add column if not exists website_url            text;

-- 2. Pending deals review queue ---------------------------------------------
-- restaurant_id is uuid to match restaurants.id (the app passes it around as a
-- lowercased uuid string). `source` stores a short label only — never a URL —
-- so neither the refresh job nor the admin UI ever surfaces source links.
create table if not exists public.pending_deals (
    id            uuid primary key default gen_random_uuid(),
    restaurant_id uuid references public.restaurants(id) on delete cascade,
    title         text not null,
    detail        text not null default '',
    source        text,                       -- 'website' | 'timeout' | 'tastecard'
    confidence    text,                       -- 'high' | 'medium' | 'low'
    status        text not null default 'pending',  -- 'pending' | 'approved' | 'rejected'
    created_at    timestamptz default now()
);

create index if not exists idx_pending_deals_status
    on public.pending_deals (status, created_at desc);
create index if not exists idx_pending_deals_restaurant
    on public.pending_deals (restaurant_id);

alter table public.pending_deals enable row level security;

-- The admin view runs as the founder's authenticated session; reads/writes are
-- gated client-side by the hardcoded founder email. Keep RLS permissive here
-- (consistent with the other app tables) — tighten later if multi-admin lands.
drop policy if exists "Read pending_deals"   on public.pending_deals;
drop policy if exists "Insert pending_deals" on public.pending_deals;
drop policy if exists "Update pending_deals" on public.pending_deals;
create policy "Read pending_deals"   on public.pending_deals for select using (true);
create policy "Insert pending_deals" on public.pending_deals for insert with check (true);
create policy "Update pending_deals" on public.pending_deals for update using (true) with check (true);
