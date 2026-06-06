-- Presentation hints for restaurant images. Logos must be shown *contained* on
-- a brand background instead of cropped (object-cover), which mangles wide
-- logos. Food photos keep the default 'cover'.
alter table public.restaurants add column if not exists image_fit text not null default 'cover'
  check (image_fit in ('cover', 'contain'));
alter table public.restaurants add column if not exists image_bg text;  -- hex bg used when image_fit = 'contain'

-- Logo-style images: contain + brand background.
update public.restaurants set image_fit = 'contain', image_bg = '#FFFFFF'
  where name ilike 'Haidilao%' or name ilike 'HEYTEA%';
update public.restaurants set image_fit = 'contain', image_bg = '#3B3A2C'  -- dark olive so the white lamb logo shows
  where name ilike 'Happy Lamb%';
