-- Add a creation timestamp to plans so lists can tie-break "earliest go-time,
-- latest created on top". Existing rows default to now(); new rows get their
-- real insert time.
alter table public.plans
    add column if not exists created_at timestamptz default now();
