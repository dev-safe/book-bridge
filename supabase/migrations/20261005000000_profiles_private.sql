-- Owner-only private profile fields (#54), phase 1.
--
-- The seller payout number (whatsapp_number) and the FCM push token move out
-- of public.profiles into public.profiles_private, readable and writable only
-- by the owner (and the service role, which the Rust payout path uses).
--
-- Phase 1 (this file): create the table, backfill it, and keep it in sync
-- with writes that still land on profiles (signup metadata via
-- handle_new_user, and older app builds that update profiles directly).
-- Phase 2 (a later migration, once old APKs are retired): null out and drop
-- profiles.whatsapp_number / profiles.fcm_token and remove the sync trigger.
create table if not exists public.profiles_private (
  id              uuid primary key references public.profiles (id) on delete cascade,
  whatsapp_number text,
  fcm_token       text,
  updated_at      timestamptz not null default now()
);

alter table public.profiles_private enable row level security;

revoke all on public.profiles_private from anon, authenticated;
grant select, insert, update on public.profiles_private to authenticated;

drop policy if exists "Owner can read own private profile" on public.profiles_private;
create policy "Owner can read own private profile"
  on public.profiles_private for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Owner can insert own private profile" on public.profiles_private;
create policy "Owner can insert own private profile"
  on public.profiles_private for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Owner can update own private profile" on public.profiles_private;
create policy "Owner can update own private profile"
  on public.profiles_private for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

insert into public.profiles_private (id, whatsapp_number, fcm_token)
select id, whatsapp_number, fcm_token
from public.profiles
where whatsapp_number is not null or fcm_token is not null
on conflict (id) do update
  set whatsapp_number = coalesce(excluded.whatsapp_number, public.profiles_private.whatsapp_number),
      fcm_token       = coalesce(excluded.fcm_token, public.profiles_private.fcm_token),
      updated_at      = now();

-- Copies non-null values written to the legacy profiles columns into
-- profiles_private. Nulls are not propagated, so a newer app that only
-- writes profiles_private is never overwritten by a stale profiles row.
create or replace function public.sync_profiles_private()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.whatsapp_number is null and new.fcm_token is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.whatsapp_number is not distinct from old.whatsapp_number
     and new.fcm_token is not distinct from old.fcm_token then
    return new;
  end if;

  insert into public.profiles_private (id, whatsapp_number, fcm_token)
  values (new.id, new.whatsapp_number, new.fcm_token)
  on conflict (id) do update
    set whatsapp_number = coalesce(excluded.whatsapp_number, public.profiles_private.whatsapp_number),
        fcm_token       = coalesce(excluded.fcm_token, public.profiles_private.fcm_token),
        updated_at      = now();
  return new;
end;
$$;

revoke all on function public.sync_profiles_private() from public, anon, authenticated;

drop trigger if exists on_profile_private_sync on public.profiles;
create trigger on_profile_private_sync
  after insert or update of whatsapp_number, fcm_token on public.profiles
  for each row execute function public.sync_profiles_private();
