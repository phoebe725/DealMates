-- Admin playbook for user-submitted price/deal reports (deal_reports).
-- Run these in the Supabase SQL Editor (service role bypasses RLS). Clients can
-- only INSERT reports and read pending ones — approving/rejecting and editing the
-- official offer is done here, by you. Nothing a user submits ever auto-applies.

-- 1) INBOX — pending reports with restaurant + current official price for context
select r.created_at,
       r.id              as report_id,
       res.name          as restaurant,
       o.title_en        as deal,
       o.price_pp        as current_price,
       r.reported_price  as suggested_price,
       r.note,
       r.reporter_name,
       r.offer_id,
       r.restaurant_id
from public.deal_reports r
left join public.restaurants      res on res.id = r.restaurant_id
left join public.restaurant_offers o   on o.id  = r.offer_id
where r.status = 'pending'
order by r.created_at desc;

-- 2) REJECT a report (wrong / spam) — just closes it, official data untouched.
update public.deal_reports
set status = 'rejected', reviewed_at = now(), reviewed_by = 'admin', updated_at = now()
where id = 'PASTE-REPORT-ID';

-- 3) APPROVE *and apply* the new price to the official offer in one go.
--    Marks the offer user_verified + stamps last_verified_at, then closes the
--    report. Replace both ids and the price.
update public.restaurant_offers
set price_pp = 15.99,                 -- the confirmed price
    price_confidence = 'user_verified',
    verified = true,
    last_verified_at = now(),
    updated_at = now()
where id = 'PASTE-OFFER-ID';

update public.deal_reports
set status = 'approved', reviewed_at = now(), reviewed_by = 'admin', updated_at = now()
where id = 'PASTE-REPORT-ID';

-- 4) APPROVE without changing the price (e.g. the report just confirms it's still
--    correct) — bumps confidence/last_verified_at and closes the report.
update public.restaurant_offers
set price_confidence = 'user_verified', verified = true, last_verified_at = now(), updated_at = now()
where id = 'PASTE-OFFER-ID';

update public.deal_reports
set status = 'approved', reviewed_at = now(), reviewed_by = 'admin', updated_at = now()
where id = 'PASTE-REPORT-ID';

-- 5) Manually (re)verify an offer yourself, no user report involved.
--    confidence: 'official' (you confirmed from the venue) | 'review_only'
--    (indicative, shows 參考價格) | 'unverified' (待確認).
update public.restaurant_offers
set price_confidence = 'official', verified = true, last_verified_at = now(), updated_at = now()
where id = 'PASTE-OFFER-ID';

-- 6) History / audit — everything you've actioned.
select status, count(*) from public.deal_reports group by status;
