insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "Avatars public read" on storage.objects;
drop policy if exists "Avatars upload" on storage.objects;
drop policy if exists "Avatars update" on storage.objects;

create policy "Avatars public read"
on storage.objects for select
using (bucket_id = 'avatars');

create policy "Avatars upload"
on storage.objects for insert
with check (bucket_id = 'avatars');

create policy "Avatars update"
on storage.objects for update
using (bucket_id = 'avatars');
