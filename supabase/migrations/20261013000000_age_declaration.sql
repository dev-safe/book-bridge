-- #55: Interim age self-declaration.
-- Users declare they are 18+ or that a parent/guardian completes purchases
-- on their behalf. This is a declaration, not a verification.
-- Columns are server-owned: no column grant is added, so clients can only
-- write them through declare_age().

alter table public.profiles
  add column if not exists age_declaration text,
  add column if not exists age_declared_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_age_declaration_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_age_declaration_check
      check (age_declaration is null or age_declaration in ('adult', 'guardian'));
  end if;
end;
$$;

create or replace function public.declare_age(p_choice text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  if p_choice is null or p_choice not in ('adult', 'guardian') then
    raise exception 'Invalid age declaration' using errcode = '22023';
  end if;

  update public.profiles
     set age_declaration = p_choice,
         age_declared_at = now()
   where id = v_uid;

  if not found then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.declare_age(text) from public, anon;
grant execute on function public.declare_age(text) to authenticated;
