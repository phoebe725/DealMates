-- Enable realtime on the `messages` table so plan/raft chat INSERTs broadcast
-- to subscribed clients. Without this, UnreadManager's listener never fires
-- for group messages (DMs already work because direct_messages was added to
-- the publication in 20260526003743_add_direct_messages.sql).
--
-- Wrapped in a DO block so it's idempotent — production may already have
-- this added via the Supabase dashboard, in which case the migration is a
-- no-op rather than failing the deploy.
do $$
begin
  if not exists (
    select 1
      from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
