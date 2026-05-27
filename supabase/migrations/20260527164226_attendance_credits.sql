-- Per-user lifetime stats: how many plans they've shown up to, and how many they've hosted.
alter table public.users
    add column if not exists attended_count int default 0,
    add column if not exists hosted_count   int default 0;

-- Plans get a confirmation timestamp once the organiser closes the books on attendance.
alter table public.plans
    add column if not exists attendance_confirmed_at timestamptz;

-- One row per (plan, member) recording whether the organiser marked them as attended.
create table if not exists public.plan_attendance (
    plan_id text not null,
    user_id text not null,
    attended boolean not null,
    recorded_at timestamptz default now(),
    primary key (plan_id, user_id)
);

alter table public.plan_attendance enable row level security;

drop policy if exists "Read attendance"   on public.plan_attendance;
drop policy if exists "Insert attendance" on public.plan_attendance;
drop policy if exists "Update attendance" on public.plan_attendance;

create policy "Read attendance"   on public.plan_attendance for select using (true);
create policy "Insert attendance" on public.plan_attendance for insert with check (true);
create policy "Update attendance" on public.plan_attendance for update using (true) with check (true);

grant select, insert, update on public.plan_attendance to anon, authenticated, service_role;

-- Atomically record attendance, bump member + organiser stats, mark plan confirmed.
create or replace function public.confirm_plan_attendance(
    p_plan_id text,
    p_attended text[]
) returns void
language plpgsql
security definer
as $$
declare
    plan_record record;
    member_id text;
begin
    select * into plan_record from public.plans where id = p_plan_id for update;
    if plan_record.id is null then
        raise exception 'Plan not found';
    end if;
    if plan_record.attendance_confirmed_at is not null then
        raise exception 'Attendance already confirmed';
    end if;

    foreach member_id in array plan_record.member_ids loop
        insert into public.plan_attendance (plan_id, user_id, attended)
        values (p_plan_id, member_id, member_id = any(p_attended))
        on conflict (plan_id, user_id) do update
        set attended = excluded.attended, recorded_at = now();
    end loop;

    if array_length(p_attended, 1) > 0 then
        update public.users
        set attended_count = coalesce(attended_count, 0) + 1
        where id = any(p_attended);

        update public.users
        set hosted_count = coalesce(hosted_count, 0) + 1
        where id = plan_record.creator_id;
    end if;

    update public.plans
    set attendance_confirmed_at = now()
    where id = p_plan_id;
end;
$$;
