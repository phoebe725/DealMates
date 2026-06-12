-- Reclassify Cheli (浙里) and New China (中華樓) as Hot Pot, and give New China the
-- AYCE offer it was missing (it had zero rows in restaurant_offers, which is why
-- no deal showed). Idempotent.

update public.restaurants
set cuisine = 'Hot Pot', cuisine_zh_hans = '火锅', cuisine_zh_hant = '火鍋'
where id in (
  'f0b8f931-f549-48a0-8487-c5c196d04c47',  -- Cheli — Elephant Park
  '67be35be-d371-4632-926d-1481b48fee37'   -- New China — Chinatown
);

-- New China — Chinatown (中華樓): £28.88/person all-you-can-eat hot pot.
insert into public.restaurant_offers
  (id, restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, price_pp, currency, is_active, category)
values
  ('d645fa08-b9f3-4072-9601-f8d1575c71f4', '67be35be-d371-4632-926d-1481b48fee37', 0,
   'AYCE Hot Pot', '火锅自助', '火鍋自助',
   '£28.88/person all-you-can-eat',
   '£28.88/人 火锅吃到饱', '£28.88/人 火鍋吃到飽',
   'other', false, true, 28.88, 'GBP', true, 'deal')
on conflict (id) do nothing;
