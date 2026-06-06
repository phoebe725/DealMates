-- XU — Soho is permanently closed; remove it from the curated set.
-- (Also removed from curated-restaurants.json + the seed migration so a fresh
-- re-seed won't reintroduce it.) Any pending_deals rows cascade via FK.
delete from public.restaurants
where id = 'f1a4b6c7-7b8e-4f2a-1d3c-4f5e7f9b3d5f';
