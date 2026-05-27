-- 1. Restore the location suffix on Ai Sushi (an earlier "better translations" migration
--    accidentally regressed it to just "Ai Sushi" with no — North Finchley qualifier, unlike
--    every other restaurant that kept its "— location" suffix).
update public.restaurants
    set name_zh_hans = 'Ai Sushi — 北芬奇利',
        name_zh_hant = 'Ai Sushi — 北芬奇利'
    where id = 'fa0e7619-0c96-44ec-b61f-02ffe33d8b2b'
      and (name_zh_hans is null or name_zh_hans not like '%—%');

-- 2. Localized deals. Same JSONB array shape as `deals`, but translated. Restaurant model
--    falls back to the English `deals` column when these are null/empty.
alter table public.restaurants
    add column if not exists deals_zh_hans jsonb,
    add column if not exists deals_zh_hant jsonb;

-- 3. Populate per restaurant. Brand names (TheFork, Tastecard, First Table, Haidilao) and
--    web addresses preserved as-is per the proper-noun rule.
update public.restaurants set
    deals_zh_hans = '[{"title":"在线订餐 9 折","detail":"通过 aisushi.co.uk 订餐可享 9 折"},{"title":"自助餐畅吃","detail":"提供自助餐 — 每轮 4 道冷盘 + 4 道热菜"}]'::jsonb,
    deals_zh_hant = '[{"title":"線上訂餐 9 折","detail":"透過 aisushi.co.uk 訂餐可享 9 折"},{"title":"自助餐暢吃","detail":"提供自助餐 — 每輪 4 道冷盤 + 4 道熱菜"}]'::jsonb
    where id = 'fa0e7619-0c96-44ec-b61f-02ffe33d8b2b';

update public.restaurants set
    deals_zh_hans = '[{"title":"单点 8 折","detail":"通过 TheFork 预订可享菜品 8 折"}]'::jsonb,
    deals_zh_hant = '[{"title":"單點 8 折","detail":"透過 TheFork 預訂可享菜品 8 折"}]'::jsonb
    where id = '0f3be145-a1c4-4b54-84dc-ef6716f24d9b';

update public.restaurants set
    deals_zh_hans = '[{"title":"通过 First Table 享 5 折","detail":"当日首场预订时段，2–4 人用餐菜品 5 折"},{"title":"Tastecard 会员 5 折","detail":"Tastecard 会员菜品 5 折（不含锅底）"}]'::jsonb,
    deals_zh_hant = '[{"title":"透過 First Table 享 5 折","detail":"當日首場預訂時段，2–4 人用餐菜品 5 折"},{"title":"Tastecard 會員 5 折","detail":"Tastecard 會員菜品 5 折（不含鍋底）"}]'::jsonb
    where id = '52a665e1-fdf3-49c1-81ba-c3434d43835a';

update public.restaurants set
    deals_zh_hans = '[]'::jsonb,
    deals_zh_hant = '[]'::jsonb
    where id = '46d28fc2-d0ed-4176-b789-e78a3d26b276';

update public.restaurants set
    deals_zh_hans = '[{"title":"自助火锅畅吃","detail":"川式火锅自助 £24.50/人（不含酒水与服务费）"}]'::jsonb,
    deals_zh_hant = '[{"title":"自助火鍋暢吃","detail":"川式火鍋自助 £24.50/人（不含酒水與服務費）"}]'::jsonb
    where id = '7540f6f8-4f57-4f71-94ce-103950805921';

update public.restaurants set
    deals_zh_hans = '[{"title":"自助火锅 £29.99 起","detail":"周一至周五下午 4 点前自助火锅，限时 90 分钟"},{"title":"学生 7.8 折","detail":"周一至周五下午 6 点前出示有效学生证可享 7.8 折（其他时段 8.8 折）"}]'::jsonb,
    deals_zh_hant = '[{"title":"自助火鍋 £29.99 起","detail":"週一至週五下午 4 點前自助火鍋，限時 90 分鐘"},{"title":"學生 7.8 折","detail":"週一至週五下午 6 點前出示有效學生證可享 7.8 折（其他時段 8.8 折）"}]'::jsonb
    where id = 'fe3c6f9d-3504-4b30-ac40-087e7819031e';

update public.restaurants set
    deals_zh_hans = '[{"title":"学生 7.8 折","detail":"周一至周四 11:00–18:00 及 22:00 后，凭学生证堂食可享 7.8 折"},{"title":"自助火锅 £29.99","detail":"周一至周五下午 4:30 前，自助标准套餐 £29.99/人（豪华套餐 £36.99）"},{"title":"£0.99 会员菜品","detail":"海底捞会员在皮卡迪利分店可享 £0.99 人气菜品"}]'::jsonb,
    deals_zh_hant = '[{"title":"學生 7.8 折","detail":"週一至週四 11:00–18:00 及 22:00 後，憑學生證堂食可享 7.8 折"},{"title":"自助火鍋 £29.99","detail":"週一至週五下午 4:30 前，自助標準套餐 £29.99/人（豪華套餐 £36.99）"},{"title":"£0.99 會員菜品","detail":"海底撈會員在皮卡迪利分店可享 £0.99 人氣菜品"}]'::jsonb
    where id = '7ffaadc0-1c28-4305-a43f-8a7b57b90249';

update public.restaurants set
    deals_zh_hans = '[{"title":"自助烧烤畅吃","detail":"炭火烧烤 + 铜锅自助 £29.99/人"}]'::jsonb,
    deals_zh_hant = '[{"title":"自助燒烤暢吃","detail":"炭火燒烤 + 銅鍋自助 £29.99/人"}]'::jsonb
    where id = '28b60ce5-9af5-40dd-ac1d-41d30da73368';

update public.restaurants set
    deals_zh_hans = '[{"title":"午市特餐","detail":"便当式午市套餐（照烧鸡、豉汁牛肉、咖喱鸡），含米饭、春卷和饮品"}]'::jsonb,
    deals_zh_hant = '[{"title":"午市特餐","detail":"便當式午市套餐（照燒雞、豉汁牛肉、咖哩雞），含米飯、春捲和飲品"}]'::jsonb
    where id = '098dcf82-89a5-4c0e-9671-a58f2d413efb';

update public.restaurants set
    deals_zh_hans = '[{"title":"牛肉自助火锅畅吃","detail":"手切牛肉自助火锅 £30.95/人，含饮品，免服务费"}]'::jsonb,
    deals_zh_hant = '[{"title":"牛肉自助火鍋暢吃","detail":"手切牛肉自助火鍋 £30.95/人，含飲品，免服務費"}]'::jsonb
    where id = '8833e03a-f43a-4974-88de-9f18ac04cb6a';

update public.restaurants set
    deals_zh_hans = '[{"title":"牛肉自助火锅畅吃","detail":"手切牛肉自助火锅 £30.95/人，含饮品，免服务费"}]'::jsonb,
    deals_zh_hant = '[{"title":"牛肉自助火鍋暢吃","detail":"手切牛肉自助火鍋 £30.95/人，含飲品，免服務費"}]'::jsonb
    where id = '105b7fbd-e54c-4ca7-bfb6-5acb52e36ee2';

update public.restaurants set
    deals_zh_hans = '[]'::jsonb,
    deals_zh_hant = '[]'::jsonb
    where id = '75ce5b67-52c1-4492-8dcd-367295d99fdb';
