-- Let users delete their own ID documents so in-app account deletion
-- (POST /account/delete in the Rust core) can purge the id-documents folder
-- with the user's own token. Must be applied BEFORE deploying that endpoint.
-- Guarded because the CI schema fixture has no storage schema.
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return;
  end if;

  drop policy if exists "id_documents_owner_delete" on storage.objects;
  create policy "id_documents_owner_delete" on storage.objects
    as permissive for delete to authenticated
    using (bucket_id = 'id-documents'
           and (storage.foldername(name))[1] = auth.uid()::text);
end
$$;
