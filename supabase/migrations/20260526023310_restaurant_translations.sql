alter table public.restaurants
    add column if not exists name_zh_hans text,
    add column if not exists name_zh_hant text,
    add column if not exists cuisine_zh_hans text,
    add column if not exists cuisine_zh_hant text;

-- Cuisine translations
update public.restaurants set
    cuisine_zh_hans = case lower(cuisine)
        when 'japanese / sushi' then '日本料理 / 寿司'
        when 'chinese' then '中餐'
        when 'hot pot' then '火锅'
        when 'japanese' then '日本料理'
        when 'sichuan' then '川菜'
        when 'hot pot / bbq' then '火锅 / 烤肉'
        else null
    end,
    cuisine_zh_hant = case lower(cuisine)
        when 'japanese / sushi' then '日本料理 / 壽司'
        when 'chinese' then '中餐'
        when 'hot pot' then '火鍋'
        when 'japanese' then '日本料理'
        when 'sichuan' then '川菜'
        when 'hot pot / bbq' then '火鍋 / 烤肉'
        else null
    end;

-- Per-restaurant name translations (location suffix kept in English).
update public.restaurants set name_zh_hans = 'Ai Sushi — 北芬奇利',         name_zh_hant = 'Ai Sushi — 北芬奇利'             where id = 'fa0e7619-0c96-44ec-b61f-02ffe33d8b2b';
update public.restaurants set name_zh_hans = '水晶中国 — 伦敦桥',           name_zh_hant = '水晶中國 — 倫敦橋'                where id = '0f3be145-a1c4-4b54-84dc-ef6716f24d9b';
update public.restaurants set name_zh_hans = '大龙燚火锅 — Fitzrovia',     name_zh_hant = '大龍燚火鍋 — Fitzrovia'           where id = '52a665e1-fdf3-49c1-81ba-c3434d43835a';
update public.restaurants set name_zh_hans = '饭家 — Farringdon/Barbican',  name_zh_hant = '飯家 — Farringdon/Barbican'      where id = '46d28fc2-d0ed-4176-b789-e78a3d26b276';
update public.restaurants set name_zh_hans = '峨眉 — 唐人街',                name_zh_hant = '峨眉 — 唐人街'                    where id = '7540f6f8-4f57-4f71-94ce-103950805921';
update public.restaurants set name_zh_hans = '海底捞 — O2',                  name_zh_hant = '海底撈 — O2'                      where id = 'fe3c6f9d-3504-4b30-ac40-087e7819031e';
update public.restaurants set name_zh_hans = '海底捞 — Piccadilly',          name_zh_hant = '海底撈 — Piccadilly'              where id = '7ffaadc0-1c28-4305-a43f-8a7b57b90249';
update public.restaurants set name_zh_hans = '炭哥 — Lambeth North',         name_zh_hant = '炭哥 — Lambeth North'             where id = '28b60ce5-9af5-40dd-ac1d-41d30da73368';
update public.restaurants set name_zh_hans = '牧羊人 — Shepherd''s Bush',    name_zh_hant = '牧羊人 — Shepherd''s Bush'        where id = '098dcf82-89a5-4c0e-9671-a58f2d413efb';
update public.restaurants set name_zh_hans = '宁记鲜牛肉火锅 — 唐人街',      name_zh_hant = '寧記鮮牛肉火鍋 — 唐人街'           where id = '8833e03a-f43a-4974-88de-9f18ac04cb6a';
update public.restaurants set name_zh_hans = '宁记鲜牛肉火锅 — Tottenham Street', name_zh_hant = '寧記鮮牛肉火鍋 — Tottenham Street' where id = '105b7fbd-e54c-4ca7-bfb6-5acb52e36ee2';
update public.restaurants set name_zh_hans = '炭家 — Shoreditch',            name_zh_hant = '炭家 — Shoreditch'                where id = '75ce5b67-52c1-4492-8dcd-367295d99fdb';
