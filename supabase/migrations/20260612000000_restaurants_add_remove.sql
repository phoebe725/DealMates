-- Discover roster update (June 2026):
--  • Remove "Mr Charcoal — Lambeth North" (碳鮮生) — temporarily closed.
--  • Add "Shu Xiang Ge — Chinatown" (蜀香格) — Sichuan hot pot, lunch AYCE £19.99.
--  • Add "113 KTV — Euston" — Korean BBQ AYCE £33 + karaoke.
--  • Add Happy Lamb — Bayswater's "Members' Wednesday" member deal (it already
--    exists as a restaurant; this just adds the new offer).
-- Idempotent: deletes are no-ops once gone; inserts use ON CONFLICT DO NOTHING.

-- 1) Remove Mr Charcoal (碳鮮生). Offers/subscriptions first in case of FKs.
delete from public.restaurant_offers       where restaurant_id = '28b60ce5-9af5-40dd-ac1d-41d30da73368';
delete from public.restaurant_subscriptions where restaurant_id = '28b60ce5-9af5-40dd-ac1d-41d30da73368';
delete from public.restaurants             where id            = '28b60ce5-9af5-40dd-ac1d-41d30da73368';

-- 2) Shu Xiang Ge — Chinatown (蜀香格): authentic Sichuan nine-grid hot pot.
insert into public.restaurants
  (id, slug, name, name_zh_hans, name_zh_hant, cuisine, cuisine_zh_hans, cuisine_zh_hant,
   address, latitude, longitude, image_url, image_fit, image_bg,
   is_featured, is_buffet, price_level, plan_count, last_deals_verified_at)
values
  ('3dde8eac-4ba3-4f4b-a84a-f80c8921a3fd', 'shu-xiang-ge-chinatown',
   'Shu Xiang Ge — Chinatown', '蜀香格 — 唐人街', '蜀香格 — 唐人街',
   'Hot Pot', '火锅', '火鍋',
   '10 Gerrard Street, London W1D 5PW', 51.5116, -0.1309,
   'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=800', 'cover', null,
   false, true, 2, 0, now())
on conflict (id) do nothing;

insert into public.restaurant_offers
  (id, restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, price_pp, currency, is_active, category)
values
  ('41f7200c-fcd9-4ada-b998-4834f20a45dc', '3dde8eac-4ba3-4f4b-a84a-f80c8921a3fd', 0,
   'Lunch All-You-Can-Eat', '午餐自助火锅', '午餐自助火鍋',
   'From £19.99/person before 17:00 · same price at weekends',
   '17:00 前 £19.99/人，周末同价', '17:00 前 £19.99/人，週末同價',
   'other', false, true, 19.99, 'GBP', true, 'deal')
on conflict (id) do nothing;

-- 3) 113 KTV — Euston: Korean BBQ buffet + karaoke.
insert into public.restaurants
  (id, slug, name, name_zh_hans, name_zh_hant, cuisine, cuisine_zh_hans, cuisine_zh_hant,
   address, latitude, longitude, image_url, image_fit, image_bg,
   is_featured, is_buffet, price_level, plan_count, last_deals_verified_at)
values
  ('eb789229-91fd-4f5f-a54d-cf56c09eb2b9', '113-ktv-euston',
   '113 KTV — Euston', '113 KTV — 尤斯顿', '113 KTV — 尤斯頓',
   'Korean', '韩国料理', '韓國料理',
   '111-113 Hampstead Road, London NW1 3EE', 51.5268, -0.1399,
   'https://images.unsplash.com/photo-1635363638580-c2809d049eee?w=800', 'cover', null,
   false, true, 2, 0, now())
on conflict (id) do nothing;

insert into public.restaurant_offers
  (id, restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, price_pp, currency, is_active, category)
values
  ('e5703514-6115-4ff9-85e8-4e32286b439b', 'eb789229-91fd-4f5f-a54d-cf56c09eb2b9', 0,
   'Korean BBQ All-You-Can-Eat', '韩式烤肉自助', '韓式烤肉自助',
   '£33/person · unlimited BBQ meats, sides & soft drinks · karaoke rooms downstairs',
   '£33/人，烤肉、小菜、饮料无限 · 楼下卡拉OK', '£33/人，烤肉、小菜、飲料無限 · 樓下卡拉OK',
   'other', false, true, 33.00, 'GBP', true, 'deal')
on conflict (id) do nothing;

-- 4) Happy Lamb — Bayswater: add the "Members' Wednesday" deal (offer_order 1).
insert into public.restaurant_offers
  (id, restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, price_pp, currency, is_active, category)
values
  ('b1f2c3d4-5e6a-47b8-9c0d-1e2f3a4b5c6d', 'a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a', 1,
   'Members'' Wednesday', '会员星期三', '會員星期三',
   'Every Wed: 3 meats AYCE £15.99/person · 2 meats unlimited £3.99/plate (soup base required)',
   '每周三：三款肉自助 £15.99/人 · 两款肉无限 £3.99/份（需点锅底）',
   '每週三：三款肉自助 £15.99/人 · 兩款肉無限 £3.99/份（需點鍋底）',
   'other', false, true, 15.99, 'GBP', true, 'deal')
on conflict (id) do nothing;
