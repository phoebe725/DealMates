-- Per-restaurant price tier (1 = £, 2 = ££, 3 = £££) so EVERY restaurant shows a
-- price level, not only those with a priced offer. Backfilled from the lowest
-- active offer price where available, otherwise defaulted to ££.
alter table public.restaurants add column if not exists price_level smallint;

with p as (
  select restaurant_id, min(price_pp) as price
  from public.restaurant_offers
  where is_active = true and price_pp is not null and price_pp > 0
  group by restaurant_id
)
update public.restaurants r
set price_level = case
  when p.price <= 15 then 1
  when p.price <= 30 then 2
  else 3
end
from p
where r.id = p.restaurant_id;

-- Everything without a priced offer defaults to ££.
update public.restaurants set price_level = 2 where price_level is null;

-- New rows that don't specify it default to ££ too. Left nullable so the iOS
-- upsert (which may send null for a freshly-pinned MapKit place) won't fail; the
-- apps treat a missing level as ££.
alter table public.restaurants alter column price_level set default 2;
