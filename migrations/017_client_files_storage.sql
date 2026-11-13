-- 017 · client file storage (Nov 13 2026)
-- The client_files table (RLS: operator owns their rows) has existed since early on, but there was
-- never a Storage bucket behind it. This adds a PRIVATE bucket for client uploads (brand files first)
-- and storage policies scoped to the uploading operator.
--
-- Object path convention: <operator_id>/<client_id>/<uuid>-<file name>
--   → the first folder must be the signed-in operator, so one operator can never read another's files.
-- The dev-team ledger downloads with the service-role key (server side, never in the browser).
-- No UPDATE policy: files are replaced by delete + upload, so a stored file can't be swapped in place.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'client-files', 'client-files', false, 20971520,
  array['image/png', 'image/jpeg', 'image/svg+xml', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

drop policy if exists "client files: operator reads own" on storage.objects;
create policy "client files: operator reads own" on storage.objects
  for select to authenticated
  using (bucket_id = 'client-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "client files: operator uploads own" on storage.objects;
create policy "client files: operator uploads own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'client-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "client files: operator deletes own" on storage.objects;
create policy "client files: operator deletes own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'client-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
