-- The `users_email_key` unique index treated every value as a duplicate,
-- including the empty-string emails the app writes for anonymous users.
-- That broke `signInAnonymously` (and therefore `signOut`, which re-signs in
-- anonymously) whenever a second anonymous account had to be created — the
-- upsert hit the unique constraint and the catch path couldn't recover.
--
-- Replace it with a partial unique index that only enforces uniqueness when
-- there's an actual email to compare. NULLs and empty strings can coexist.

alter table public.users drop constraint if exists users_email_key;
drop index if exists public.users_email_key;

create unique index users_email_key
    on public.users (email)
    where email is not null and email <> '';
