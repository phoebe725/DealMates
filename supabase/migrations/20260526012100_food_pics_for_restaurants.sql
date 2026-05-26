-- Replace all restaurant images with cuisine-keyed food photos (Unsplash).
update public.restaurants
set image_url = case lower(coalesce(cuisine, ''))
    when 'japanese / sushi' then 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800'
    when 'japanese'         then 'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?w=800'
    when 'chinese'          then 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800'
    when 'sichuan'          then 'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=800'
    when 'hot pot'          then 'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800'
    when 'hot pot / bbq'    then 'https://images.unsplash.com/photo-1582450871972-ab5ca641643d?w=800'
    else                         'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800'
end;
