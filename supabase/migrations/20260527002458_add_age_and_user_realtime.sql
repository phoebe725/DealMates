alter table public.users
    add column if not exists age int;

-- Enable realtime so the profile sheet can subscribe to live updates of a user row.
alter publication supabase_realtime add table public.users;
