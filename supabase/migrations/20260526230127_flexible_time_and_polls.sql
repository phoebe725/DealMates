-- Flexible time mode for plans (Weekday/Weekend × Lunch/Dinner, no specific date/time).
alter table public.plans
    add column if not exists time_type text default 'asap',
    add column if not exists flex_day text,
    add column if not exists flex_meal text;

update public.plans
set time_type = case when is_asap then 'asap' else 'scheduled' end
where time_type is null or time_type not in ('asap', 'scheduled', 'flexible');

-- Polls: anyone in a plan can create a poll, anyone can vote (one vote per user per poll).
create table if not exists public.polls (
    id uuid primary key default gen_random_uuid(),
    plan_id text not null,
    creator_id text not null,
    creator_name text not null,
    question text not null,
    options jsonb not null,
    created_at timestamptz default now()
);
create index if not exists idx_polls_plan_id on public.polls(plan_id);

create table if not exists public.poll_votes (
    poll_id uuid not null references public.polls(id) on delete cascade,
    user_id text not null,
    option_index int not null,
    voted_at timestamptz default now(),
    primary key (poll_id, user_id)
);

alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;

drop policy if exists "Read polls" on public.polls;
drop policy if exists "Insert polls" on public.polls;
drop policy if exists "Read poll_votes" on public.poll_votes;
drop policy if exists "Manage poll_votes" on public.poll_votes;

create policy "Read polls" on public.polls for select using (true);
create policy "Insert polls" on public.polls for insert with check (true);
create policy "Read poll_votes" on public.poll_votes for select using (true);
create policy "Manage poll_votes" on public.poll_votes for all using (true) with check (true);

grant select, insert on public.polls to anon, authenticated, service_role;
grant select, insert, update, delete on public.poll_votes to anon, authenticated, service_role;

alter publication supabase_realtime add table public.polls;
alter publication supabase_realtime add table public.poll_votes;
