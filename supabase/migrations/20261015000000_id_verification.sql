-- #34 / #36: Age-based ID verification, reviewed by an admin.
--
--   age 10-14 : child's school ID + guardian's CNI on the same account;
--               payments and payouts use the guardian's Mobile Money number.
--   age 15-17 : school ID.
--   age 18+   : CNI (Carte Nationale d'Identite).
--   under 10  : not allowed.
--
-- Unverified users can browse and list, but cannot buy books or receive
-- payouts (enforced by the Rust service). ID images live in the private
-- `id-documents` bucket under `{uid}/` and are deleted once an admin approves
-- or rejects them; only the status, ID type, reviewer and reason are kept.
--
-- All new profile columns are server-owned: no client column grant is added,
-- so clients write them only through submit_id_verification(). They are not
-- added to public_profiles except the derived `id_verified` flag.

-- 1. Profile columns ---------------------------------------------------------
alter table public.profiles
  add column if not exists date_of_birth          date,
  add column if not exists id_verification_status text not null default 'unverified',
  add column if not exists id_type                text,
  add column if not exists guardian_phone         text,
  add column if not exists id_document_paths      text[] not null default '{}',
  add column if not exists id_submitted_at        timestamptz,
  add column if not exists id_reviewed_by         uuid references auth.users (id),
  add column if not exists id_reviewed_at         timestamptz,
  add column if not exists id_rejection_reason    text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_id_verification_status_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_id_verification_status_check
      check (id_verification_status in ('unverified', 'pending', 'verified', 'rejected'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_id_type_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_id_type_check
      check (id_type is null or id_type in ('school_id', 'cni'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_guardian_phone_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_guardian_phone_check
      check (guardian_phone is null or guardian_phone ~ '^6[0-9]{8}$');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_id_rejection_reason_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_id_rejection_reason_check
      check (id_rejection_reason is null or char_length(id_rejection_reason) between 1 and 1000);
  end if;
end;
$$;

create index if not exists profiles_id_pending_idx
  on public.profiles (id_submitted_at)
  where id_verification_status = 'pending';

-- 2. Submission RPC ------------------------------------------------------------
-- p_guardian_phone is required for ages 10-14 and ignored otherwise.
-- p_document_paths must be objects the caller uploaded under `{uid}/` in the
-- id-documents bucket: one for 15+, two (school ID + guardian CNI) for 10-14.
create or replace function public.submit_id_verification(
  p_date_of_birth  date,
  p_document_paths text[],
  p_guardian_phone text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_status  text;
  v_age     int;
  v_phone   text;
  v_paths   text[];
  v_needed  int;
  v_path    text;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  select id_verification_status into v_status
    from public.profiles where id = v_uid for update;
  if not found then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;
  if v_status = 'verified' then
    raise exception 'Identity already verified' using errcode = '55000';
  end if;
  if v_status = 'pending' then
    raise exception 'A verification is already under review' using errcode = '55000';
  end if;

  if p_date_of_birth is null or p_date_of_birth > current_date then
    raise exception 'Invalid date of birth' using errcode = '22023';
  end if;
  v_age := extract(year from age(current_date, p_date_of_birth))::int;
  if v_age < 10 then
    raise exception 'BookBridge is for users aged 10 and over' using errcode = '22023';
  end if;
  if v_age > 120 then
    raise exception 'Invalid date of birth' using errcode = '22023';
  end if;

  v_paths := coalesce(array_remove(p_document_paths, null), '{}');
  v_needed := case when v_age < 15 then 2 else 1 end;
  if cardinality(v_paths) < v_needed or cardinality(v_paths) > 4 then
    raise exception 'Expected % ID photo(s)', v_needed using errcode = '22023';
  end if;
  foreach v_path in array v_paths loop
    if v_path not like v_uid::text || '/%' or v_path like '%..%' then
      raise exception 'Invalid document path' using errcode = '22023';
    end if;
  end loop;

  if v_age < 15 then
    v_phone := regexp_replace(coalesce(p_guardian_phone, ''), '[^0-9]', '', 'g');
    if v_phone like '237%' and length(v_phone) > 9 then
      v_phone := substr(v_phone, 4);
    end if;
    if v_phone !~ '^6[0-9]{8}$' then
      raise exception 'A valid guardian Mobile Money number is required' using errcode = '22023';
    end if;
  else
    v_phone := null;
  end if;

  update public.profiles
     set date_of_birth          = p_date_of_birth,
         id_type                = case when v_age < 18 then 'school_id' else 'cni' end,
         guardian_phone         = v_phone,
         id_document_paths      = v_paths,
         id_verification_status = 'pending',
         id_submitted_at        = now(),
         id_reviewed_by         = null,
         id_reviewed_at         = null,
         id_rejection_reason    = null
   where id = v_uid;
end;
$$;

revoke all on function public.submit_id_verification(date, text[], text) from public, anon;
grant execute on function public.submit_id_verification(date, text[], text) to authenticated;

-- 3. Admin audit trail ---------------------------------------------------------
-- The action check was declared inline, so Postgres named it
-- admin_actions_action_check.
alter table public.admin_actions
  add column if not exists target_user_id uuid references auth.users (id) on delete set null;

alter table public.admin_actions drop constraint if exists admin_actions_action_check;
alter table public.admin_actions
  add constraint admin_actions_action_check check (action in (
    'release_dispute', 'refund_dispute',
    'refund_unmatched', 'dismiss_unmatched',
    'approve_id', 'reject_id'));

create index if not exists admin_actions_target_user_id_idx
  on public.admin_actions (target_user_id)
  where target_user_id is not null;

-- 4. Public "verified" badge ---------------------------------------------------
-- Appended at the end so CREATE OR REPLACE VIEW keeps the column order.
-- Date of birth, guardian phone and document paths are never exposed.
create or replace view public.public_profiles as
select
  id,
  full_name,
  locality,
  avatar_url,
  rating,
  review_count,
  trust_score,
  trust_level,
  completed_deals_count,
  created_at,
  tier,
  (id_verification_status = 'verified') as id_verified
from public.profiles;

revoke all on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to anon, authenticated;

-- 5. Private storage bucket ----------------------------------------------------
-- Guarded because the CI schema fixture has no storage schema.
do $$
begin
  if not exists (select 1 from pg_namespace where nspname = 'storage') then
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('id-documents', 'id-documents', false, 5242880,
          array['image/jpeg', 'image/png', 'image/webp'])
  on conflict (id) do update
    set public = false,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

  drop policy if exists "id_documents_owner_insert" on storage.objects;
  create policy "id_documents_owner_insert" on storage.objects
    as permissive for insert to authenticated
    with check (bucket_id = 'id-documents'
                and (storage.foldername(name))[1] = auth.uid()::text);

  drop policy if exists "id_documents_owner_select" on storage.objects;
  create policy "id_documents_owner_select" on storage.objects
    as permissive for select to authenticated
    using (bucket_id = 'id-documents'
           and (storage.foldername(name))[1] = auth.uid()::text);

  drop policy if exists "id_documents_admin_select" on storage.objects;
  create policy "id_documents_admin_select" on storage.objects
    as permissive for select to authenticated
    using (bucket_id = 'id-documents'
           and exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

  drop policy if exists "id_documents_admin_delete" on storage.objects;
  create policy "id_documents_admin_delete" on storage.objects
    as permissive for delete to authenticated
    using (bucket_id = 'id-documents'
           and exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
end;
$$;
