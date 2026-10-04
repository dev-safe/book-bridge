-- #39 Power Seller subscription + 3-listing free tier.
--
-- Free sellers may have at most 3 'available' listings at a time. Power
-- Sellers (paid 30-day subscription via Fapshi, confirmed by the Rust
-- webhook) are uncapped. Policy for existing over-cap free sellers:
-- GRANDFATHER — their current listings stay live, but they cannot post a
-- new one until they drop below 3 (sell/delete) or upgrade.

-- 1. profiles.tier ------------------------------------------------------------
-- Server-owned: no client UPDATE grant is added for this column, so only the
-- service role (Rust webhook) and SECURITY DEFINER jobs can change it.
alter table public.profiles
  add column if not exists tier text not null default 'free'
    constraint profiles_tier_check check (tier in ('free', 'power_seller'));

-- Expose tier publicly (badge on seller profiles). Column appended at the end
-- so CREATE OR REPLACE VIEW keeps the existing column order.
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
  tier
from public.profiles;

revoke all on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to anon, authenticated;

-- 2. subscriptions --------------------------------------------------------------
create table if not exists public.subscriptions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles (id) on delete cascade,
  tier             text not null default 'power_seller'
                     check (tier in ('power_seller')),
  status           text not null default 'active'
                     check (status in ('active', 'expired', 'cancelled')),
  fapshi_reference text not null unique,
  amount           integer not null check (amount >= 0),
  started_at       timestamptz not null default now(),
  expires_at       timestamptz not null,
  created_at       timestamptz not null default now()
);

create index if not exists subscriptions_user_active_idx
  on public.subscriptions (user_id, expires_at)
  where status = 'active';

alter table public.subscriptions enable row level security;

drop policy if exists subscriptions_select_own on public.subscriptions;
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.subscriptions from public, anon, authenticated;
grant select on public.subscriptions to authenticated;

-- 3. upgrade_codes ----------------------------------------------------------------
-- Short-lived, single-use codes minted by the Rust service for an
-- authenticated app user; the landing page redeems one to start web checkout
-- without a web login. Never readable by clients.
create table if not exists public.upgrade_codes (
  code       text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '15 minutes'),
  used_at    timestamptz,
  trans_id   text,
  created_at timestamptz not null default now()
);

create index if not exists upgrade_codes_trans_id_idx
  on public.upgrade_codes (trans_id);

alter table public.upgrade_codes enable row level security;
revoke all on public.upgrade_codes from public, anon, authenticated;

-- 4. Free-tier listing cap ----------------------------------------------------------
create or replace function public.check_listing_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier text;
  v_active integer;
begin
  if coalesce(new.status, 'available') <> 'available' then
    return new;
  end if;

  select tier into v_tier from public.profiles where id = new.seller_id;
  if coalesce(v_tier, 'free') <> 'free' then
    return new;
  end if;

  -- Serialise concurrent inserts by the same seller so two parallel inserts
  -- cannot both see a count of 2.
  perform pg_advisory_xact_lock(hashtext('listing_limit:' || new.seller_id::text));

  select count(*) into v_active
  from public.listings
  where seller_id = new.seller_id
    and status = 'available';

  if v_active >= 3 then
    raise exception 'free_tier_limit'
      using errcode = 'P0001',
            hint = 'Free sellers can have 3 active listings. Upgrade to Power Seller for unlimited listings.';
  end if;

  return new;
end;
$$;

revoke all on function public.check_listing_limit() from public, anon, authenticated;

drop trigger if exists trg_check_listing_limit on public.listings;
create trigger trg_check_listing_limit
  before insert on public.listings
  for each row execute function public.check_listing_limit();

-- 5. Expiry --------------------------------------------------------------------------
create or replace function public.expire_power_sellers()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_downgraded integer;
begin
  update public.subscriptions
     set status = 'expired'
   where status = 'active'
     and expires_at <= now();

  update public.profiles p
     set tier = 'free'
   where p.tier = 'power_seller'
     and not exists (
       select 1 from public.subscriptions s
        where s.user_id = p.id
          and s.status = 'active'
          and s.expires_at > now()
     );
  get diagnostics v_downgraded = row_count;
  return v_downgraded;
end;
$$;

revoke all on function public.expire_power_sellers() from public, anon, authenticated;

select cron.unschedule('expire-power-sellers')
where exists (select 1 from cron.job where jobname = 'expire-power-sellers');

select cron.schedule(
  'expire-power-sellers',
  '15 0 * * *',
  $$select public.expire_power_sellers();$$
);
