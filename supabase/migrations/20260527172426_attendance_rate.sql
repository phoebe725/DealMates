-- Track the denominator for attendance rate: every time a plan's attendance is confirmed,
-- every member's record_count increments — regardless of whether they actually showed up.
-- Rate = attended_count / attendance_record_count.

alter table public.users
    add column if not exists attendance_record_count int default 0;

-- Backfill existing rows: at minimum, attendance_record_count >= attended_count.
update public.users
   set attendance_record_count = greatest(coalesce(attendance_record_count, 0), coalesce(attended_count, 0));

-- Rewrite the confirmation function to also bump the denominator for every member.
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

    -- Every member gets +1 to the denominator.
    update public.users
       set attendance_record_count = coalesce(attendance_record_count, 0) + 1
     where id = any(plan_record.member_ids);

    -- Only attended members get +1 to the numerator.
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
