-- Price/deal verification system (MVP).
--
-- 1) Verification fields ON the official offer records (read-only to clients —
--    no write policy exists, so users can never edit official data directly).
-- 2) A SEPARATE user-report table (deal_reports): clients may INSERT a report and
--    READ only *pending* ones (to show "price may have changed"); they cannot
--    update/approve/overwrite anything. Approving is a service-role/admin step.

-- ---- 1) Official offer verification fields --------------------------------
alter table public.restaurant_offers
  add column if not exists verified         boolean not null default false,
  add column if not exists price_confidence text    not null default 'unverified',
  add column if not exists last_verified_at timestamptz,
  add column if not exists source_note      text;

alter table public.restaurant_offers drop constraint if exists restaurant_offers_price_confidence_chk;
alter table public.restaurant_offers
  add constraint restaurant_offers_price_confidence_chk
  check (price_confidence in ('official', 'user_verified', 'review_only', 'unverified'));

-- Backfill: existing offers were hand-curated from official sources → 'official'.
update public.restaurant_offers
set verified = true,
    price_confidence = 'official',
    last_verified_at = coalesce(last_verified_at, updated_at, created_at, now())
where price_confidence = 'unverified';

-- ...except the two we flagged "please reconfirm" → review_only (參考價格).
update public.restaurant_offers
set verified = false, price_confidence = 'review_only'
where id in (
  '66e702eb-0988-4931-9dc1-11c2b146cc6b',  -- Aroma Buffet
  'e3551a1a-f21a-400c-8fd3-acff9245e704'   -- Golden Buffet
);

-- ---- 2) User report table (separate from official data) ------------------
create table if not exists public.deal_reports (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  text not null,
  offer_id       text,                       -- which deal it's about (optional)
  reporter_id    text,
  reporter_name  text,
  reported_price numeric,                     -- suggested corrected price (optional)
  note           text,                        -- free-text correction
  status         text not null default 'pending'
                   check (status in ('pending', 'approved', 'rejected')),
  reviewed_by    text,
  reviewed_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists idx_deal_reports_restaurant on public.deal_reports (restaurant_id, status);
create index if not exists idx_deal_reports_offer      on public.deal_reports (offer_id, status);

alter table public.deal_reports enable row level security;

-- Anyone may submit a report.
drop policy if exists deal_reports_insert on public.deal_reports;
create policy deal_reports_insert on public.deal_reports
  for insert to anon, authenticated with check (true);

-- Anyone may read only PENDING reports (drives the "price may have changed"
-- note); approved/rejected history stays server-side only. No update/delete
-- policy exists, so clients can't change status or touch official records.
drop policy if exists deal_reports_select_pending on public.deal_reports;
create policy deal_reports_select_pending on public.deal_reports
  for select to anon, authenticated using (status = 'pending');

grant insert, select on public.deal_reports to anon, authenticated;
