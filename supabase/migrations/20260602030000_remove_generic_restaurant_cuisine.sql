-- Remove venues that ended up with the placeholder "Restaurant" (or other
-- generic Apple-Maps) cuisine — these were created by the MapKit add/pin flow
-- before a real cuisine was set, and show up as a junk "Restaurant" filter chip.
-- pending_deals rows cascade via FK.
delete from public.restaurants
where cuisine in ('Restaurant', 'Cafe', 'Bakery');
