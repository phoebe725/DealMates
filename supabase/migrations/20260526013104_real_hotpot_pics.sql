update public.restaurants
set image_url = 'https://images.unsplash.com/photo-1614104030967-5ca61a54247b?w=800'
where lower(cuisine) = 'hot pot';

update public.restaurants
set image_url = 'https://images.unsplash.com/photo-1611345157614-26d3bdd10c93?w=800'
where lower(cuisine) = 'hot pot / bbq';
