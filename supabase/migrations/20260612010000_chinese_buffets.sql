-- Add six Chinese all-you-can-eat buffets to Discover (June 2026). cuisine
-- "Chinese" + is_buffet so they group under the existing Chinese cuisine chip and
-- the AYCE/Buffet deal filter; each gets a buffet "deal" offer carrying the price.
-- price_level: £ for <=£15/pp, ££ otherwise. Coordinates are postcode-approximate.
-- Idempotent via ON CONFLICT DO NOTHING.

insert into public.restaurants
  (id, slug, name, name_zh_hans, name_zh_hant, cuisine, cuisine_zh_hans, cuisine_zh_hant,
   address, latitude, longitude, image_url, image_fit, image_bg,
   is_featured, is_buffet, price_level, plan_count, last_deals_verified_at)
values
  ('d3c67ffc-c6eb-4d12-98a2-a5d59d42141a', 'noodles-city-camberwell',
   'Noodles City — Camberwell', '面城自助餐 — 坎伯韦尔', '麵城自助餐 — 坎伯韋爾',
   'Chinese', '中餐', '中餐', '21-22 Camberwell Green, London SE5 7AA', 51.4740, -0.0935,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 1, 0, now()),
  ('20526b86-8a32-4e63-ae0c-747e691f82da', 'mr-wu-chinatown',
   'Mr Wu — Chinatown', '吴先生自助餐 — 唐人街', '吳先生自助餐 — 唐人街',
   'Chinese', '中餐', '中餐', '28 Wardour Street, London W1D 6QN', 51.5112, -0.1312,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 1, 0, now()),
  ('735093c7-0ef6-4194-8e5b-31663aecf64f', 'young-cheng-chinatown',
   'Young Cheng — Chinatown', '阳城自助餐 — 唐人街', '陽城自助餐 — 唐人街',
   'Chinese', '中餐', '中餐', '39 Wardour Street, London W1D 6PX', 51.5116, -0.1313,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 2, 0, now()),
  ('4e446147-f7b4-4aee-a504-c521e3ddd61b', 'jj-buffet-chinatown',
   'JJ Buffet — Chinatown', '金聚自助餐 — 唐人街', '金聚自助餐 — 唐人街',
   'Chinese', '中餐', '中餐', '12 Newport Place, London WC2H 7PR', 51.5113, -0.1299,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 2, 0, now()),
  ('f2b35812-61d5-4380-af88-123523682fbd', 'aroma-buffet-shepherds-bush',
   'Aroma Buffet — Shepherd''s Bush', '香味阁自助餐 — 牧人丛林', '香味閣自助餐 — 牧人叢林',
   'Chinese', '中餐', '中餐', 'West 12 Shopping Centre, Shepherd''s Bush, London W12 8PP', 51.5065, -0.2205,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 2, 0, now()),
  ('f2132680-377e-44db-b387-4ab211bfbc6f', 'golden-buffet-tottenham',
   'Golden Buffet — Tottenham', '金龙自助餐 — 托特纳姆', '金龍自助餐 — 托特納姆',
   'Chinese', '中餐', '中餐', '131-133 High Cross Road, London N17 9NU', 51.5950, -0.0700,
   'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800', 'cover', null,
   false, true, 1, 0, now())
on conflict (id) do nothing;

insert into public.restaurant_offers
  (id, restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, price_pp, currency, is_active, category)
values
  ('8bc8588e-13be-4eb1-a29b-c0b72b7ef622', 'd3c67ffc-c6eb-4d12-98a2-a5d59d42141a', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · £9 weekdays / £10 weekends · takeaway £4/box',
   '自助餐 · 工作日 £9 / 周末 £10 · 外带 £4/盒', '自助餐 · 工作日 £9 / 週末 £10 · 外帶 £4/盒',
   'other', false, true, 9.00, 'GBP', true, 'deal'),
  ('cc6f59ff-72ed-48b5-88b2-e45436e48981', '20526b86-8a32-4e63-ae0c-747e691f82da', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · £9.95/person dine-in · takeaway £5/box',
   '自助餐 · 堂食 £9.95/人 · 外带 £5/盒', '自助餐 · 堂食 £9.95/人 · 外帶 £5/盒',
   'other', false, true, 9.95, 'GBP', true, 'deal'),
  ('7f702ae9-0c96-41cf-9321-f3e7250b889f', '735093c7-0ef6-4194-8e5b-31663aecf64f', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · £16/person',
   '自助餐 · £16/人', '自助餐 · £16/人',
   'other', false, true, 16.00, 'GBP', true, 'deal'),
  ('a35bdadd-576a-444d-8c24-93a846bcfbdb', '4e446147-f7b4-4aee-a504-c521e3ddd61b', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · £16 Mon–Thu / £18.50 Fri–Sun · takeaway £10/box',
   '自助餐 · 周一至周四 £16 / 周五至周日 £18.50 · 外带 £10/盒',
   '自助餐 · 週一至週四 £16 / 週五至週日 £18.50 · 外帶 £10/盒',
   'other', false, true, 16.00, 'GBP', true, 'deal'),
  ('66e702eb-0988-4931-9dc1-11c2b146cc6b', 'f2b35812-61d5-4380-af88-123523682fbd', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · lunch ~£18.99 / dinner ~£24.99 (please reconfirm)',
   '自助餐 · 午餐约 £18.99 / 晚餐约 £24.99（建议再确认）',
   '自助餐 · 午餐約 £18.99 / 晚餐約 £24.99（建議再確認）',
   'other', false, true, 18.99, 'GBP', true, 'deal'),
  ('e3551a1a-f21a-400c-8fd3-acff9245e704', 'f2132680-377e-44db-b387-4ab211bfbc6f', 0,
   'All-You-Can-Eat Buffet', '自助餐', '自助餐',
   'All-you-can-eat · £12.99/person (please reconfirm)',
   '自助餐 · £12.99/人（建议再确认）', '自助餐 · £12.99/人（建議再確認）',
   'other', false, true, 12.99, 'GBP', true, 'deal')
on conflict (id) do nothing;
