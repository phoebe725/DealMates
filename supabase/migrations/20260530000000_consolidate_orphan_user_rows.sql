-- When a user's `public.users.id` doesn't match their `auth.users.id` for the
-- same email, `auth.uid()::text = id` is false and RLS denies every update.
-- The app's UI sees "Couldn't save your profile" because the update returns
-- zero rows.
--
-- This happens in practice when a user signs up a second time with the same
-- email: the new auth.users row gets a new UUID, but the public.users
-- fallback path (on the unique-email constraint violation) returns the
-- pre-existing row — leaving `currentUser.id` pointing at a stale UID.
--
-- This migration consolidates all such orphans, then adds a `consolidate_user_by_email`
-- RPC that the app can call going forward so the same drift can be repaired
-- automatically on sign-in.

-- ─── 1. Function to consolidate a single user row ─────────────────────────────

create or replace function public.consolidate_user_by_email(
    target_email text,
    new_uid text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    orphan_id text;
    canonical_exists boolean;
begin
    if target_email is null or target_email = '' or new_uid is null or new_uid = '' then
        return;
    end if;

    -- The orphan is whichever row carries the email but with a stale id.
    select id into orphan_id
    from public.users
    where email = target_email and id <> new_uid
    limit 1;

    if orphan_id is null then return; end if;

    -- Migrate every FK reference to point at the new uid. These are plain text
    -- columns (no FK constraints), so we update them one table at a time.
    update public.plans set creator_id = new_uid where creator_id = orphan_id;
    update public.plans set member_ids = array_replace(member_ids, orphan_id, new_uid) where orphan_id = any(member_ids);
    update public.plans set reported_by = array_replace(reported_by, orphan_id, new_uid) where orphan_id = any(reported_by);
    update public.messages set sender_id = new_uid where sender_id = orphan_id;
    update public.direct_messages set sender_id = new_uid where sender_id = orphan_id;
    update public.direct_messages set recipient_id = new_uid where recipient_id = orphan_id;
    update public.polls set creator_id = new_uid where creator_id = orphan_id;
    update public.poll_votes set user_id = new_uid where user_id = orphan_id;
    update public.restaurant_subscriptions set user_id = new_uid where user_id = orphan_id;
    update public.device_tokens set user_id = new_uid where user_id = orphan_id;
    -- system message args reference user uids inside a jsonb array
    update public.messages
        set system_args = (
            select jsonb_agg(case when value::text = to_jsonb(orphan_id)::text then to_jsonb(new_uid) else value end)
            from jsonb_array_elements(system_args)
        )
        where system_args is not null
          and system_args::text like '%' || orphan_id || '%';
    -- another user's block list / reported plans may reference the orphan id
    update public.users set blocked_users = array_replace(blocked_users, orphan_id, new_uid)
        where orphan_id = any(blocked_users);

    -- Now reconcile the public.users rows themselves. Two cases:
    --   • A canonical row already exists for new_uid → merge the orphan's
    --     profile + counters into it, then delete the orphan.
    --   • No canonical row yet → just re-point the orphan's id.
    select exists(select 1 from public.users where id = new_uid) into canonical_exists;

    if canonical_exists then
        update public.users c
        set
            display_name            = coalesce(nullif(o.display_name, ''), c.display_name),
            bio                     = coalesce(nullif(o.bio, ''), c.bio),
            avatar_url              = coalesce(o.avatar_url, c.avatar_url),
            gender                  = coalesce(o.gender, c.gender),
            age                     = coalesce(o.age, c.age),
            attended_count          = greatest(c.attended_count, coalesce(o.attended_count, 0)),
            attendance_record_count = greatest(c.attendance_record_count, coalesce(o.attendance_record_count, 0)),
            hosted_count            = greatest(c.hosted_count, coalesce(o.hosted_count, 0)),
            blocked_users           = (
                select coalesce(array_agg(distinct x), '{}'::text[])
                from unnest(c.blocked_users || coalesce(o.blocked_users, '{}'::text[])) x
            ),
            reported_plans          = (
                select coalesce(array_agg(distinct x), '{}'::text[])
                from unnest(c.reported_plans || coalesce(o.reported_plans, '{}'::text[])) x
            ),
            is_anonymous            = false,
            updated_at              = now()
        from public.users o
        where c.id = new_uid and o.id = orphan_id;

        delete from public.users where id = orphan_id;
    else
        update public.users
            set id = new_uid, is_anonymous = false, updated_at = now()
            where id = orphan_id;
    end if;
end;
$$;

grant execute on function public.consolidate_user_by_email(text, text)
    to anon, authenticated, service_role;

-- ─── 2. One-shot cleanup of all existing orphans ─────────────────────────────

do $$
declare
    rec record;
begin
    for rec in
        select pu.email, au.id::text as auth_id
        from public.users pu
        join auth.users au on au.email = pu.email
        where pu.email is not null and pu.email <> ''
          and pu.id <> au.id::text
    loop
        perform public.consolidate_user_by_email(rec.email, rec.auth_id);
    end loop;
end$$;
