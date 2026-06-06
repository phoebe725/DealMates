-- Single explicit classification for each offer, driving the Deals experience.
--   group_gated = needs multiple people to unlock (buy X get Y, 2–4 diners, group set menu)
--   deal        = a real offer: AYCE pricing, lunch sets, %/student/member discounts
--   highlight   = descriptive restaurant info only (accolades, amenities, à la carte
--                 menu pricing, "famous for…") — never surfaced as a deal
alter table public.restaurant_offers add column if not exists category text;

-- Baseline: group-gated rows are authoritative; everything else starts as a deal.
update public.restaurant_offers
   set category = case when is_group_gated then 'group_gated' else 'deal' end;

-- Reclassify the descriptive blurbs to highlight (id-independent, matched by title
-- so it reproduces on a fresh DB). These carry no actual offer — just restaurant info.
update public.restaurant_offers set category = 'highlight'
 where not is_group_gated and (
       title_en in (
         'Karaoke room available', 'Generous portions', 'Famous roast duck',
         'Renowned roast meats', 'Newest branch', 'First UK store',
         'Affordable Korean street food', 'All-day dim sum',
         'Daily dim sum, weekend queues', 'Tem Toh tasting menu',
         'Affordable BBQ rice / noodle sets'
       )
       or title_en like 'Michelin Bib Gourmand%'
       or title_en like 'Michelin Guide Sichuan%'
       or title_en like '49 dim sum dishes%'
       or title_en like 'Original tonkotsu ramen%'
       or title_en like 'Chongqing xiaomian%'
       or title_en like 'Hand-pulled biang biang noodles%'
       or title_en like 'Thai BBQ bar%'
 );

-- Keep the legacy is_deal_like flag consistent with the new source of truth.
update public.restaurant_offers set is_deal_like = (category <> 'highlight');

alter table public.restaurant_offers alter column category set default 'deal';
alter table public.restaurant_offers alter column category set not null;
alter table public.restaurant_offers drop constraint if exists restaurant_offers_category_check;
alter table public.restaurant_offers add constraint restaurant_offers_category_check
  check (category in ('group_gated', 'deal', 'highlight'));

create index if not exists idx_restaurant_offers_category
  on public.restaurant_offers (restaurant_id, category);
