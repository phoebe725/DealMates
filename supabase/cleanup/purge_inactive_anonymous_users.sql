-- Purge inactive anonymous ("guest") users.
--
-- The app signs every fresh launch in anonymously so people can browse before
-- creating an account (see AuthViewModel.bootstrap → AuthService.signInAnonymously).
-- Each of those guests gets a row in public.users with an empty email and a
-- "Diner###" placeholder name (is_anonymous = true). In development especially
-- — every simulator reset, reinstall, or cleared keychain — these accumulate
-- as "empty users".
--
-- This script removes guest rows that have NO real activity: never created or
-- joined a plan, never sent a message or DM, never voted in / created a poll,
-- never recorded attendance, and never subscribed to a restaurant. Anyone with
-- any of those is kept. It also deletes the underlying anonymous auth.users
-- records (which cascades to their sessions/identities) so they don't simply
-- get re-materialised on the next app launch.
--
-- This is intentionally NOT under supabase/migrations/ so `supabase db push`
-- never runs it automatically. Run it from the Supabase dashboard SQL editor.
--
-- SAFETY: registered accounts (non-empty email) are never touched. The
-- `created_at` guard skips guests created in the last day so a brand-new guest
-- mid-sign-up isn't removed. Run the preview SELECT first to see the count.
--
-- To preview WITHOUT deleting, run just this:
--
--   select count(*) from public.users u
--   where coalesce(u.email,'') = ''
--     and coalesce(u.is_anonymous,false) = true
--     and u.created_at < now() - interval '1 day'
--     and not exists (select 1 from public.plans p where p.creator_id = u.id)
--     and not exists (select 1 from public.plans p where u.id = any(p.member_ids))
--     and not exists (select 1 from public.messages m where m.sender_id = u.id)
--     and not exists (select 1 from public.direct_messages d where d.sender_id = u.id or d.recipient_id = u.id)
--     and not exists (select 1 from public.polls pl where pl.creator_id = u.id)
--     and not exists (select 1 from public.poll_votes v where v.user_id = u.id)
--     and not exists (select 1 from public.plan_attendance a where a.user_id = u.id)
--     and not exists (select 1 from public.restaurant_subscriptions s where s.user_id = u.id);

begin;

create temporary table _purge_uids on commit drop as
select u.id
from public.users u
where coalesce(u.email, '') = ''
  and coalesce(u.is_anonymous, false) = true
  and u.created_at < now() - interval '1 day'
  and not exists (select 1 from public.plans p                  where p.creator_id = u.id)
  and not exists (select 1 from public.plans p                  where u.id = any(p.member_ids))
  and not exists (select 1 from public.messages m               where m.sender_id = u.id)
  and not exists (select 1 from public.direct_messages d        where d.sender_id = u.id or d.recipient_id = u.id)
  and not exists (select 1 from public.polls pl                 where pl.creator_id = u.id)
  and not exists (select 1 from public.poll_votes v             where v.user_id = u.id)
  and not exists (select 1 from public.plan_attendance a        where a.user_id = u.id)
  and not exists (select 1 from public.restaurant_subscriptions s where s.user_id = u.id);

-- How many will be removed (shows in the editor results pane).
select count(*) as users_to_purge from _purge_uids;

-- Remove auto-created rows that aren't counted as "activity".
delete from public.device_tokens where user_id in (select id from _purge_uids);

-- Remove the empty profile rows.
delete from public.users where id in (select id from _purge_uids);

-- Remove the underlying anonymous auth users. public.users.id is the lowercased
-- auth uid string, so match on lower(id::text). Deleting from auth.users
-- cascades to the auth-owned sessions/identities/refresh tokens.
delete from auth.users
where is_anonymous = true
  and lower(id::text) in (select id from _purge_uids);

commit;
