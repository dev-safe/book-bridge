-- Fix: ID uploads failed with "permission denied for table admin_users".
--
-- The id-documents admin policies queried public.admin_users directly, but
-- clients have no grant on that table. Storage evaluates every SELECT policy
-- on upload (INSERT ... RETURNING), so even non-admin uploads hit the error.
-- The check now goes through a SECURITY DEFINER function that only answers
-- "is the caller an admin?".

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admin_users a where a.user_id = auth.uid());
$$;

revoke all on function public.current_user_is_admin() from public, anon;
grant execute on function public.current_user_is_admin() to authenticated;

do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return;
  end if;

  drop policy if exists "id_documents_admin_select" on storage.objects;
  create policy "id_documents_admin_select" on storage.objects
    as permissive for select to authenticated
    using (bucket_id = 'id-documents' and public.current_user_is_admin());

  drop policy if exists "id_documents_admin_delete" on storage.objects;
  create policy "id_documents_admin_delete" on storage.objects
    as permissive for delete to authenticated
    using (bucket_id = 'id-documents' and public.current_user_is_admin());
end;
$$;
