alter table "public"."users"
  add column if not exists "avatar_url" text;

alter table "public"."plans"
  add column if not exists "creator_avatar_url" text;

update "public"."plans" p
set creator_avatar_url = u.avatar_url
from "public"."users" u
where p.creator_id = u.id
  and p.creator_avatar_url is null
  and u.avatar_url is not null;
