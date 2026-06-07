-- Human-readable, sequential, unique member number per user — the user-facing
-- ID. Doubles as the source of the guest display name ("Diner<member_no>"),
-- replacing the old random "Diner100–999" which collided.

-- 1. Sequence + column.
create sequence if not exists public.users_member_no_seq;
alter table public.users add column if not exists member_no bigint;

-- 2. Backfill existing rows in signup order (oldest = #1).
with ordered as (
  select id, row_number() over (order by created_at nulls last, id) as rn
  from public.users
)
update public.users u
set member_no = ordered.rn
from ordered
where u.id = ordered.id and u.member_no is null;

-- 3. Continue the sequence after the highest backfilled value, then make it the
--    default for new rows and enforce uniqueness.
select setval('public.users_member_no_seq',
              coalesce((select max(member_no) from public.users), 0) + 1, false);
alter table public.users alter column member_no set default nextval('public.users_member_no_seq');
alter sequence public.users_member_no_seq owned by public.users.member_no;
alter table public.users alter column member_no set not null;
create unique index if not exists users_member_no_key on public.users (member_no);

-- 4. New users with no chosen name (guests) get "Diner<member_no>"; registered
--    users keep the name they entered. AFTER INSERT so member_no is populated.
create or replace function public.set_default_diner_name() returns trigger
language plpgsql as $$
begin
  if new.display_name is null or btrim(new.display_name) = '' then
    update public.users set display_name = 'Diner' || new.member_no where id = new.id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_default_diner_name on public.users;
create trigger trg_default_diner_name
  after insert on public.users
  for each row execute function public.set_default_diner_name();

-- 5. Fix existing guests: replace the old collidable random "Diner###" (and any
--    blank) names with the sequential one. Registered accounts are left alone.
update public.users
set display_name = 'Diner' || member_no
where coalesce(is_anonymous, false) = true
  and (display_name is null or btrim(display_name) = '' or display_name ~ '^Diner[0-9]{3}$');
