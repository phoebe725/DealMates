-- Merge the "Japanese / Sushi" cuisine into plain "Japanese".
-- Clears the per-row Chinese cuisine overrides so the label falls back to the
-- AppLocale.localizedCuisine helper (日本料理 / 日本料理), keeping it consistent
-- with the curated venues that carry no cuisine_zh_* values.
update public.restaurants
set cuisine = 'Japanese',
    cuisine_zh_hans = null,
    cuisine_zh_hant = null
where lower(replace(cuisine, ' ', '')) in ('japanese/sushi', 'sushi');
