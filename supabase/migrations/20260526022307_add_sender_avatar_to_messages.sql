alter table "public"."messages"
  add column if not exists "sender_avatar_url" text;
