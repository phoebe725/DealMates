-- Split the catch-all "FOR ALL" policy on poll_votes into per-action policies.
-- The FOR ALL form sometimes doesn't apply cleanly to DELETE; per-action is more reliable.

drop policy if exists "Manage poll_votes" on public.poll_votes;
drop policy if exists "Select poll_votes" on public.poll_votes;
drop policy if exists "Insert poll_votes" on public.poll_votes;
drop policy if exists "Delete poll_votes" on public.poll_votes;
drop policy if exists "Update poll_votes" on public.poll_votes;

create policy "Select poll_votes" on public.poll_votes for select using (true);
create policy "Insert poll_votes" on public.poll_votes for insert with check (true);
create policy "Delete poll_votes" on public.poll_votes for delete using (true);
create policy "Update poll_votes" on public.poll_votes for update using (true) with check (true);
