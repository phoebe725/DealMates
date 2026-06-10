-- Plan datetime columns were `timestamp without time zone`, which silently
-- dropped the timezone the apps send. Both clients write a UTC instant (iOS
-- `.iso8601` -> "…T17:00:00Z", web `toISOString()` -> "…T17:00:00.000Z"); a
-- tz-less column stored the bare "17:00:00" and handed it back with no offset.
-- iOS then read that as UTC (-> 6pm BST) while JS `new Date()` read it as local
-- (-> 5pm), so the two platforms disagreed by exactly the local UTC offset and
-- edits could never "stick". Converting to timestamptz preserves the offset the
-- clients already send, so reads are unambiguous and identical everywhere.
--
-- The existing bare values were all written as UTC wall-clock numbers, so we
-- reinterpret them AT TIME ZONE 'UTC' (i.e. "these numbers were already UTC").
-- Guarded so it only converts columns still stored without a timezone — safe to
-- re-run and a no-op once applied.
do $$
declare
  col text;
begin
  foreach col in array array['scheduled_at', 'expires_at', 'attendance_confirmed_at']
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'plans'
        and column_name = col and data_type = 'timestamp without time zone'
    ) then
      execute format(
        'alter table public.plans alter column %I type timestamptz using %I at time zone ''UTC''',
        col, col
      );
    end if;
  end loop;
end $$;
