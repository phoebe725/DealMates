-- restaurant_offers: normalized offers (one row per deal), focused on group-gated
-- offers. The restaurants table stays the source of truth for identity/location;
-- restaurants.deals* JSON columns are kept for backward-compatible fallback.
create table if not exists public.restaurant_offers (
    id                  uuid primary key default gen_random_uuid(),
    restaurant_id       uuid not null references public.restaurants(id) on delete cascade,
    offer_order         int  not null default 0,
    title_en            text,
    title_zh_hans       text,
    title_zh_hant       text,
    description_en      text,
    description_zh_hans text,
    description_zh_hant text,
    offer_type          text not null default 'other'
                            check (offer_type in ('buy_x_get_y','group_set_menu','min_diners_discount','other')),
    is_group_gated      boolean not null default false,
    is_deal_like        boolean not null default true,
    min_people          int,
    max_people          int,
    price_pp            numeric(8,2),
    currency            text not null default 'GBP',
    source_url          text,
    valid_from          timestamptz,
    valid_until         timestamptz,
    is_active           boolean not null default true,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create index if not exists idx_restaurant_offers_restaurant
    on public.restaurant_offers (restaurant_id, offer_order);

alter table public.restaurant_offers enable row level security;
drop policy if exists "Read restaurant_offers"   on public.restaurant_offers;
drop policy if exists "Insert restaurant_offers" on public.restaurant_offers;
drop policy if exists "Update restaurant_offers" on public.restaurant_offers;
create policy "Read restaurant_offers"   on public.restaurant_offers for select using (true);
create policy "Insert restaurant_offers" on public.restaurant_offers for insert with check (true);
create policy "Update restaurant_offers" on public.restaurant_offers for update using (true) with check (true);

-- Migrate existing deals (idempotent: only seeds when the table is still empty).
insert into public.restaurant_offers
  (restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
   description_en, description_zh_hans, description_zh_hant,
   offer_type, is_group_gated, is_deal_like, min_people, max_people, price_pp,
   currency, source_url, valid_from, valid_until, is_active)
select * from (values
  ('fa0e7619-0c96-44ec-b61f-02ffe33d8b2b'::uuid, 0, '10% off online orders', '在线订餐 9 折', '線上訂餐 9 折', '10% off when ordering via aisushi.co.uk', '通过 aisushi.co.uk 订餐可享 9 折', '透過 aisushi.co.uk 訂餐可享 9 折', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('fa0e7619-0c96-44ec-b61f-02ffe33d8b2b', 1, 'All-you-can-eat buffet', '自助餐畅吃', '自助餐暢吃', 'AYCE buffet available — 4 cold + 4 hot dishes per round', '提供自助餐 — 每轮 4 道冷盘 + 4 道热菜', '提供自助餐 — 每輪 4 道冷盤 + 4 道熱菜', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('e9f3a5b6-6a7d-4e1f-9c2b-3e4d6e8a2c4e', 0, 'Karaoke room available', 'KTV包间', 'KTV包間', 'Borough branch has private KTV rooms for group bookings', 'Borough分店设有团体KTV包间', 'Borough分店設有團體KTV包間', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('d8e2f4a5-5f6c-4d9e-8b1a-2d3c5d7f1b3d', 0, 'Michelin Bib Gourmand 9 years running', '米其林必比登推荐9年', '米其林必比登推薦9年', 'Famous Taiwanese steamed buns £3.50–£5.50 (Classic £5.50). Walk-in only, queues common.', '招牌台式刈包 £3.50–£5.50（经典款 £5.50）。仅接受现场，常需排队。', '招牌台式刈包 £3.50–£5.50（經典款 £5.50）。僅接受現場，常需排隊。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('b3c67e8f-9d1a-4b4c-3f5e-6b7a9b2d5f7b', 0, 'Michelin Guide Sichuan, mains £12–14', '米其林指南川菜，主菜 £12–14', '米其林指南川菜，主菜 £12–14', '18-year-old Sichuan pioneer in London. Most mains £12–14, chillies/peppers imported from China. Vegetarian options available.', '伦敦川菜先锋18年。多数主菜£12–14，辣椒花椒直接从中国进口，提供素食选项', '倫敦川菜先鋒18年。多數主菜£12–14，辣椒花椒直接從中國進口，提供素食選項', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('a8b2d4e5-5c6f-4a9b-8e1d-2a3f5a7c1e3a', 0, 'Lunch deal £10 (main + side)', '午市特惠 £10（主菜+配菜）', '午市特惠 £10（主菜+配菜）', '1 side + 1 main for £10, 7 items each to choose from (including signature pho). 24-hour simmered pho broth.', '1配菜+1主菜£10，各7款可选（含招牌牛肉河粉）。汤底慢熬24小时。', '1配菜+1主菜£10，各7款可選（含招牌牛肉河粉）。湯底慢熬24小時。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('0f3be145-a1c4-4b54-84dc-ef6716f24d9b', 0, '20% off a la carte', '单点 8 折', '單點 8 折', '20% off food when you book via TheFork', '通过 TheFork 预订可享菜品 8 折', '透過 TheFork 預訂可享菜品 8 折', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('52a665e1-fdf3-49c1-81ba-c3434d43835a', 0, '50% off via First Table', '通过 First Table 享 5 折', '透過 First Table 享 5 折', '50% off food bill for 2–4 diners on the first booking slot of the day', '当日首场预订时段，2–4 人用餐菜品 5 折', '當日首場預訂時段，2–4 人用餐菜品 5 折', 'min_diners_discount', true, true, 2, 4, NULL, 'GBP', NULL, NULL, NULL, true),
  ('52a665e1-fdf3-49c1-81ba-c3434d43835a', 1, '50% off with Tastecard', 'Tastecard 会员 5 折', 'Tastecard 會員 5 折', '50% off food for Tastecard members (excludes soup base)', 'Tastecard 会员菜品 5 折（不含锅底）', 'Tastecard 會員菜品 5 折（不含鍋底）', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('cdea95aa-de47-4d48-856a-3765065cd97f', 0, 'All-you-can-eat BBQ & Hotpot', '自助烧烤火锅', '自助燒烤火鍋', '£35/adult · £25/child — 2 hour limit', '£35/成人 · £25/儿童，限时2小时', '£35/成人 · £25/兒童，限時2小時', 'other', false, true, NULL, NULL, 35, 'GBP', NULL, NULL, NULL, true),
  ('e0f7cf51-cd68-40ef-914d-54da5499c8b5', 0, 'All-you-can-eat BBQ & Hotpot', '自助烧烤火锅', '自助燒烤火鍋', '£35/adult · £25/child — 2 hour limit', '£35/成人 · £25/儿童，限时2小时', '£35/成人 · £25/兒童，限時2小時', 'other', false, true, NULL, NULL, 35, 'GBP', NULL, NULL, NULL, true),
  ('2e905009-8485-4deb-8451-ae1847e6b834', 0, 'All-you-can-eat BBQ & Hotpot', '自助烧烤火锅', '自助燒烤火鍋', '£35/adult · £25/child — 2 hour limit', '£35/成人 · £25/儿童，限时2小时', '£35/成人 · £25/兒童，限時2小時', 'other', false, true, NULL, NULL, 35, 'GBP', NULL, NULL, NULL, true),
  ('f7a1b3c4-4b5e-4f8a-7d9c-1f2e4f6b9d2f', 0, '49 dim sum dishes, 12pm–5pm daily', '49款点心，每日 12pm–5pm', '49款點心，每日 12pm–5pm', 'Family-run with specialist dim sum chefs. Steamed, fried, and cheung fun rice noodle rolls. South London''s best dim sum destination.', '家族经营，专业点心师傅。蒸点、炸点、肠粉。南伦敦最佳点心去处。', '家族經營，專業點心師傅。蒸點、炸點、腸粉。南倫敦最佳點心去處。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('a2b5c7d8-8c9f-4a3b-2e4d-5a6f8a1c4e6a', 0, 'Generous portions', '份量超值', '份量超值', 'Known for large bento and sushi sets at affordable prices', '便当及寿司套餐分量大、价格实惠', '便當及壽司套餐分量大、價格實惠', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('7540f6f8-4f57-4f71-94ce-103950805921', 0, 'Spicy steam pot buffet', '冒菜自助', '冒菜自助', 'Unlimited Sichuan spicy steam pot £19.9pp with rice(incl. drinks & service)', '冒菜自助含米饭 £19.9/人（含饮料与服务费）', '冒菜自助含米飯 £19.9/人（含飲料與服務費）', 'other', false, true, NULL, NULL, 19.9, 'GBP', NULL, NULL, NULL, true),
  ('d2e5f7a8-8f9c-4d3e-2b4a-5d6c8d1f4b6d', 0, 'Famous roast duck', '招牌烧鸭', '招牌燒鴨', 'Renowned for Cantonese roast duck', '粤式烧鸭闻名于伦敦', '粵式燒鴨聞名於倫敦', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('e3f6a8b9-9a1d-4e4f-3c5b-6e7d9e2a5c7e', 0, 'Renowned roast meats', '招牌烧腊', '招牌燒臘', 'Cantonese BBQ duck and roast pork specialties', '粤式烧鸭、叉烧、烧肉著称', '粵式燒鴨、叉燒、燒肉著稱', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('fe3c6f9d-3504-4b30-ac40-087e7819031e', 0, 'AYCE hotpot from £29.99', '自助火锅 £29.99', '自助火鍋 £29.99', 'Buy 4 get 1 free for all-you-can-eat hotpot Mon–Fri before 4pm, Mon-Thu after 830 - 930pm', '买4送1 周一至周五下午 4 点前, 周一至周四晚上8:30到9:30之后 自助火锅', '買4送1，週一至週五下午 4 點前，週一至週四晚上 8:30 到 9:30 之後，自助火鍋', 'buy_x_get_y', true, true, 4, NULL, 29.99, 'GBP', NULL, NULL, NULL, true),
  ('fe3c6f9d-3504-4b30-ac40-087e7819031e', 1, 'AYCE hotpot from £36.99', '自助火锅 £36.99', '自助火鍋 £36.99', 'Buy 4 get 1 free for all-you-can-eat hotpot Mon–Thu 4pm - 8:30pm, Fri 4pm - 9:30pm, Sat & Sun before 4pm', '买4送1 周一至周四下午 4 点到晚上 8:30, 周五下午 4 点到晚上 9:30，周六周日下午 4 点前 自助火锅', '買4送1，週一至週四下午 4 點到晚上 8:30，週五下午 4 點到晚上 9:30，週六週日下午 4 點前，自助火鍋', 'buy_x_get_y', true, true, 4, NULL, 36.99, 'GBP', NULL, NULL, NULL, true),
  ('fe3c6f9d-3504-4b30-ac40-087e7819031e', 2, '22% student discount', '学生 7.8 折', '學生 7.8 折', '22% off with valid student ID before 6pm Mon–Fri (12% off other times)', '周一至周五下午 6 点前出示有效学生证可享 7.8 折（其他时段 8.8 折）', '週一至週五下午 6 點前出示有效學生證可享 7.8 折（其他時段 8.8 折）', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('7ffaadc0-1c28-4305-a43f-8a7b57b90249', 0, '22% student discount', '学生 7.8 折', '學生 7.8 折', '22% off Mon–Thu 11:00–18:00 and after 22:00 with student ID, dine-in only', '周一至周四 11:00–18:00 及 22:00 后，凭学生证堂食可享 7.8 折', '週一至週四 11:00–18:00 及 22:00 後，憑學生證堂食可享 7.8 折', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('7ffaadc0-1c28-4305-a43f-8a7b57b90249', 1, 'AYCE hotpot £29.99', '自助火锅 £29.99', '自助火鍋 £29.99', 'All-you-can-eat standard set £29.99pp (deluxe £36.99), min. 2 ppl, Mon–Fri before 5:00pm', '周一至周五下午 5:00 前，自助标准套餐 £29.99/人（豪华套餐 £36.99），两位起订', '週一至週五下午 4:30 前，自助標準套餐 £29.99/人（豪華套餐 £36.99），兩位起訂', 'min_diners_discount', true, true, 2, NULL, 29.99, 'GBP', NULL, NULL, NULL, true),
  ('7ffaadc0-1c28-4305-a43f-8a7b57b90249', 2, '£0.99 member dishes', '£0.99 会员菜品', '£0.99 會員菜品', 'Haidilao members get popular dishes for £0.99 at Piccadilly branch', '海底捞会员在皮卡迪利分店可享 £0.99 人气菜品', '海底撈會員在皮卡迪利分店可享 £0.99 人氣菜品', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a', 0, 'All-you-can-eat Hotpot', '自助火锅', '自助火鍋', 'From £19.99/person (weekday lunch) · weekend from £30/person', '工作日午市低至 £19.99/人，周末低至 £30/人', '工作日午市低至 £19.99/人，週末低至 £30/人', 'other', false, true, NULL, NULL, 19.99, 'GBP', NULL, NULL, NULL, true),
  ('1a6f9e8f-3e93-4e72-aafb-5617310bbe3b', 0, 'All-you-can-eat Hotpot', '自助火锅', '自助火鍋', 'From £19.99/person (weekday lunch) · weekend from £30/person', '工作日午市低至 £19.99/人，周末低至 £30/人', '工作日午市低至 £19.99/人，週末低至 £30/人', 'other', false, true, NULL, NULL, 19.99, 'GBP', NULL, NULL, NULL, true),
  ('4d5e6f7a-8b9c-1d2e-3f4a-5b6c7d8e9f1a', 0, 'Newest branch', '最新分店', '最新分店', 'Opened July 2025', '2025年7月开业', '2025年7月開業', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('1a2b3c4d-5e6f-7a8b-9c1d-2e3f4a5b6c7d', 0, 'First UK store', '英国首家门店', '英國首家門店', 'Original London branch opened August 2023, signature cheese tea and fruit tea', '2023年8月开业，招牌芝士茶与果茶', '2023年8月開業，招牌芝士茶與果茶', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('955e387c-ee1f-4a77-8c8b-de80c5fb7595', 0, 'Unlimited BBQ', '无限烧烤', '無限燒烤', '£22.80/person — 8 cuts of meat, all you can eat', '£22.80/人，8种肉类任食', '£22.80/人，8種肉類任食', 'other', false, true, NULL, NULL, 22.8, 'GBP', NULL, NULL, NULL, true),
  ('d5e8f1a2-2f3c-4d6e-5b7a-8d9c2d4f7b9d', 0, 'Original tonkotsu ramen £16.95', '正宗豚骨拉面 £16.95', '正宗豚骨拉麵 £16.95', '18-hour pork-bone broth, hand-made noodles, chashu pork belly. Truffle ramen £20.95. From Fukuoka, Japan.', '18小时熬制猪骨汤底，手工面条，叉烧。松露拉面£20.95。源自日本福冈。', '18小時熬製豬骨湯底，手工麵條，叉燒。松露拉麵£20.95。源自日本福岡。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('d8e23a4b-5f6c-4d9e-8b1a-2e3f5c7d9b1d', 0, 'Chongqing xiaomian noodles £10–20', '重庆小面 £10–20/人', '重慶小麵 £10–20/人', 'London''s first Chongqing noodle bar. Pork/beef/vegan xiaomian or hot-and-sour glass noodles, customisable spice levels.', '伦敦首家重庆小面馆。猪肉/牛肉/素小面或酸辣粉，辣度可调。', '倫敦首家重慶小麵館。豬肉/牛肉/素小麵或酸辣粉，辣度可調。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('28b60ce5-9af5-40dd-ac1d-41d30da73368', 0, 'All-you-can-eat BBQ', '自助烧烤畅吃', '自助燒烤暢吃', 'Unlimited charcoal BBQ & copper hotpot £29.99pp', '炭火烧烤 + 铜锅自助 £29.99/人', '炭火燒烤 + 銅鍋自助 £29.99/人', 'other', false, true, NULL, NULL, 29.99, 'GBP', NULL, NULL, NULL, true),
  ('098dcf82-89a5-4c0e-9671-a58f2d413efb', 0, 'Lunch special menu', '午市特餐', '午市特餐', 'Bento-style lunch sets (chicken teriyaki, beef black bean, curry chicken) with rice, spring rolls & drink', '便当式午市套餐（照烧鸡、豉汁牛肉、咖喱鸡），含米饭、春卷和饮品', '便當式午市套餐（照燒雞、豉汁牛肉、咖哩雞），含米飯、春捲和飲品', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('d5e89a1b-2f3c-4d6e-5b7a-8d9c2d4f7b9d', 0, 'Hand-pulled biang biang noodles £6–14', '手工biangbiang面 £6–14', '手工biangbiang麵 £6–14', 'London''s first Xi''an restaurant. Hand-pulled noodles made in front of guests. Murgers (Chinese sandwiches) £7.50. Branches: Euston, Mayfair, City, Elephant & Castle.', '伦敦首家西安菜。现场手工拉面表演。肉夹馍£7.50/个。分店：尤斯顿、梅菲尔、金融城、大象堡', '倫敦首家西安菜。現場手工拉麵表演。肉夾饃£7.50/個。分店：尤斯頓、梅菲爾、金融城、大象堡', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('8833e03a-f43a-4974-88de-9f18ac04cb6a', 0, 'All-you-can-eat beef hotpot', '牛肉自助火锅畅吃', '牛肉自助火鍋暢吃', 'Unlimited hand-cut beef hotpot £30.95pp, drinks included, no service charge', '手切牛肉自助火锅 £30.95/人，含饮品，免服务费', '手切牛肉自助火鍋 £30.95/人，含飲品，免服務費', 'other', false, true, NULL, NULL, 30.95, 'GBP', NULL, NULL, NULL, true),
  ('105b7fbd-e54c-4ca7-bfb6-5acb52e36ee2', 0, 'All-you-can-eat beef hotpot', '牛肉自助火锅畅吃', '牛肉自助火鍋暢吃', 'Unlimited hand-cut beef hotpot £30.95pp, drinks included, no service charge', '手切牛肉自助火锅 £30.95/人，含饮品，免服务费', '手切牛肉自助火鍋 £30.95/人，含飲品，免服務費', 'other', false, true, NULL, NULL, 30.95, 'GBP', NULL, NULL, NULL, true),
  ('f7a1c3d4-4b5e-4f8a-7d9c-1f2e4f6b9d2f', 0, 'Affordable Korean street food', '平价韩式街头小吃', '平價韓式街頭小吃', 'Bibimbap £7.50, kimchi bokeum bab £8.50, sides £2. Walk-in only, lunch specials available.', '石锅拌饭£7.50，泡菜炒饭£8.50，配菜£2。仅接受现场，提供午市特惠。', '石鍋拌飯£7.50，泡菜炒飯£8.50，配菜£2。僅接受現場，提供午市特惠。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('9c42c076-792f-4d8f-a119-068c7d689256', 0, 'AYCE Malatang', '自助麻辣烫', '自助麻辣燙', '£19.90/person all-you-can-eat malatang', '£19.90/人，无限自助麻辣烫', '£19.90/人，無限自助麻辣燙', 'other', false, true, NULL, NULL, 19.9, 'GBP', NULL, NULL, NULL, true),
  ('a8b2c4d5-5c6f-4a9b-8e1d-2a3f5a7c1e3a', 0, 'Dim sum set 8 items £12.50', '8款点心套餐 £12.50', '8款點心套餐 £12.50', 'All-day dim sum service. 10-piece sampler £10. Individual items £4–5. Larger set menus from £38pp.', '全天点心服务。10件试吃拼盘£10。单点£4–5/份。套餐£38起/人。', '全天點心服務。10件試吃拼盤£10。單點£4–5/份。套餐£38起/人。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('b9c3d5e6-6d7a-4b1c-9f2e-3b4a6b8d2f4b', 0, 'All-day dim sum', '全天点心服务', '全天點心服務', 'Dim sum service 12pm–5pm daily, Sunday from 11am (last orders 4:45pm). 300+ menu items.', '每日 12pm–5pm 供应点心，周日 11am 开始（最后点单 4:45pm）。菜单 300+ 道菜', '每日 12pm–5pm 供應點心，週日 11am 開始（最後點單 4:45pm）。菜單 300+ 道菜', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('1b52d32d-eeb0-471a-94bf-2fc736f75cf1', 0, 'All-you-can-eat Hotpot', '自助火锅', '自助火鍋', '£32.80/person · 90 min · halal · 50+ ingredients', '£32.80/人，90分钟，清真，50+食材', '£32.80/人，90分鐘，清真，50+食材', 'other', false, true, NULL, NULL, 32.8, 'GBP', NULL, NULL, NULL, true),
  ('c1d4e6f7-7e8b-4c2d-1a3f-4c5b7c9e3a5c', 0, 'Daily dim sum, weekend queues', '每日点心，周末需排队', '每日點心，週末需排隊', 'Dim sum served daily (no booking for dim sum service). Weekend queues form by 10:50am — arrive early. 13% service charge applies.', '每日供应点心（点心时段不接受预订）。周末早上 10:50 就开始排队 — 务必提前。账单加 13% 服务费。', '每日供應點心（點心時段不接受預訂）。週末早上 10:50 就開始排隊 — 務必提前。賬單加 13% 服務費。', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('2272f145-26e1-43c3-8316-7f8bfed56b3a', 0, 'All-you-can-eat BBQ Hotpot', '自助烧烤火锅', '自助燒烤火鍋', 'Mon–Thu £36/person · Fri–Sun £38/person', '周一至周四 £36/人 · 周五至周日 £38/人', '週一至週四 £36/人 · 週五至週日 £38/人', 'other', false, true, NULL, NULL, 36, 'GBP', NULL, NULL, NULL, true),
  ('c4d7e9f1-1e2b-4c5d-4a6f-7c8b1c3e6a8c', 0, '3-course lunch set £29', '三道菜午市套餐 £29', '三道菜午市套餐 £29', 'Starter + ramen + drink (tea/coffee/0.0% beer). Any day, anytime. Standalone ramen from £10.', '前菜+拉面+饮品（茶/咖啡/0.0%啤酒），全天供应。单点拉面£10起。', '前菜+拉麵+飲品（茶/咖啡/0.0%啤酒），全天供應。單點拉麵£10起。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('b9c3e5f6-6d7a-4b1c-9f2e-3b4a6b8d2f4b', 0, 'Thai BBQ bar, small plates from £4', '泰式烧烤吧，小盘菜£4起', '泰式燒烤吧，小盤菜£4起', 'Famous chilli fish sauce wings £7. Tom yum prawn mama noodles £14. Sai oua, Tamworth skewers, Mangalitsa pork chop. Thai BBQ specialist.', '招牌辣鱼露鸡翅£7。冬阴功虾妈妈面£14。泰式香肠、烤串、猪肉。泰式烧烤专家。', '招牌辣魚露雞翅£7。冬陰功蝦媽媽麵£14。泰式香腸、烤串、豬肉。泰式燒烤專家。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('c1d4f6a7-7e8b-4c2d-1a3f-4c5b7c9e3a5c', 0, 'Tem Toh tasting menu', 'Tem Toh 品尝菜单', 'Tem Toh 品嚐菜單', 'Set tasting menu featuring fishcakes + red curry. Most a la carte mains around £15. Regional Thai dishes in a former fabric warehouse.', '套餐品尝菜单含鱼饼+红咖喱。单点主菜约£15。前布料仓库改造，地方泰国菜。', '套餐品嚐菜單含魚餅+紅咖哩。單點主菜約£15。前布料倉庫改造，地方泰國菜。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('b3c6d8e9-9d1a-4b4c-3f5e-6b7a9b2d5f7b', 0, 'Weekday lunch £10.50', '工作日午市 £10.50', '工作日午市 £10.50', 'Lunch-sized ramen or hiyashi noodle salad + lunch-sized side £10.50, Mon–Fri until 5pm (excl. bank holidays). Regular ramen £16.50–£16.75.', '小份拉面或冷面+小份配菜£10.50，周一至周五至 5pm（节假日除外）。正常拉面£16.50–£16.75。', '小份拉麵或冷麵+小份配菜£10.50，週一至週五至 5pm（節假日除外）。正常拉麵£16.50–£16.75。', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('b6c9d2e3-3d4a-4b7c-6f8e-9b1a3b5d8f1b', 0, 'Affordable BBQ rice / noodle sets', '经济实惠烧腊饭面', '經濟實惠燒臘飯麵', 'Known for budget-friendly Cantonese set meals', '粤式平价套餐著称', '粵式平價套餐著稱', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('a5b8c1d2-2c3f-4a6b-5e7d-8a9f2a4c7e9a', 0, 'Hand-pulled biang biang noodles', '手工biangbiang面', '手工biangbiang麵', 'Specialty Shaanxi hand-pulled noodles', '陕西手工拉面招牌', '陝西手工拉麵招牌', 'other', false, false, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e', 0, 'Lunch set £23.50pp', '午市套餐 £23.50/人', '午市套餐 £23.50/人', 'Dim sum + signature main + ice cream/sorbet + cold-pressed juice or tea, Mon–Fri 11am–5pm', '点心+招牌主菜+冰淇淋/雪芭+冷压果汁或茶，周一至周五 11am–5pm', '點心+招牌主菜+冰淇淋/雪芭+冷壓果汁或茶，週一至週五 11am–5pm', 'other', false, true, NULL, NULL, 23.5, 'GBP', NULL, NULL, NULL, true),
  ('e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e', 1, 'Infinite Yum Cha', '无限畅吃点心', '無限暢吃點心', 'Unlimited dim sum and bao available, vegetarian/vegan options on request', '点心和包无限畅吃，提供素食/纯素选项', '點心和包無限暢吃，提供素食/純素選項', 'other', false, true, NULL, NULL, NULL, 'GBP', NULL, NULL, NULL, true),
  ('e6f9b2c3-3a4d-4e7f-6c8b-9e1d3e5a8c1e', 0, 'BBQ Half & Half Set for 2', '双拼烧烤套餐 (2人份)', '雙拼燒烤套餐 (2人份)', 'Signature shared BBQ set. NOT all-you-can-eat — banchan and condiments charged separately.', '招牌双拼烧烤套餐。非自助 — 小菜与酱料另计。', '招牌雙拼燒烤套餐。非自助 — 小菜與醬料另計。', 'group_set_menu', true, true, 2, 2, NULL, 'GBP', NULL, NULL, NULL, true),
  ('e210ad68-01bd-4b80-a781-048cd6c349c5', 0, 'AYCE Malatang', '自助麻辣烫', '自助麻辣燙', '£19.90/person all-you-can-eat malatang', '£19.90/人，无限自助麻辣烫', '£19.90/人，無限自助麻辣燙', 'other', false, true, NULL, NULL, 19.9, 'GBP', NULL, NULL, NULL, true)
) as v(restaurant_id, offer_order, title_en, title_zh_hans, title_zh_hant,
       description_en, description_zh_hans, description_zh_hant,
       offer_type, is_group_gated, is_deal_like, min_people, max_people, price_pp,
       currency, source_url, valid_from, valid_until, is_active)
where not exists (select 1 from public.restaurant_offers);
