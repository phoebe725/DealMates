-- DESTRUCTIVE — wipes every user, plan, message, DM, subscription, device
-- token, and poll in the database. Run from the Supabase dashboard's SQL
-- editor when you want to reset the app to a clean state.
--
-- This is intentionally NOT placed under supabase/migrations/ so `supabase db
-- push` will never replay it accidentally. Copy-paste the body into the SQL
-- editor and click Run — review the row counts before confirming.
--
-- Order matters: delete dependents before parents to satisfy FKs. Restaurants
-- + restaurant_deals are preserved as reference data; if you want those gone
-- too, uncomment the trailing blocks.

begin;

-- 1. Chat content
delete from public.messages;
delete from public.direct_messages;

-- 2. Plan-scoped state
delete from public.poll_votes;
delete from public.polls;

-- 3. Plans themselves
delete from public.plans;

-- 4. User-restaurant relationships
delete from public.restaurant_subscriptions;

-- 5. Push token registry
delete from public.device_tokens;

-- 6. User profile rows
delete from public.users;

-- 7. Auth users (Supabase-managed). Cascades clean up identities + sessions.
delete from auth.users;

-- Reference data — uncomment ONLY if you want a totally blank slate.
-- delete from public.restaurant_deals;
-- delete from public.restaurants;

commit;

-- Sanity check — should all return 0 after the commit.
select
  (select count(*) from auth.users)               as auth_users,
  (select count(*) from public.users)             as profile_users,
  (select count(*) from public.plans)             as plans,
  (select count(*) from public.messages)          as plan_messages,
  (select count(*) from public.direct_messages)   as direct_messages,
  (select count(*) from public.polls)             as polls;
