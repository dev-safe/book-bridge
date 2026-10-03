-- Local test database for the DB integration tests: the production tables
-- the Rust service touches, with production's column types, defaults and
-- constraints (captured from the live schema on 2026-10-03), plus a stub
-- auth.users, auth.uid() and the Supabase API roles. Triggers, RLS policies and the
-- tables the service never reads are left out.
--
-- Load it into a throwaway local Postgres, apply the migrations newer than
-- this snapshot (20261003000000_admin_dispute_resolution.sql onwards), then
--   DATABASE_URL=postgres://postgres@127.0.0.1:<port>/postgres cargo test
-- Never load this into a real Supabase project.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;

create schema if not exists auth;
create table auth.users (
  id    uuid primary key,
  email text
);

-- Stub so migrations that define RLS policies load; the service role the
-- tests connect as bypasses RLS anyway.
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create table public.app_secrets (
  key   text primary key,
  value text not null
);

create table public.profiles (
  id                    uuid primary key references auth.users (id),
  email                 text,
  full_name             text,
  locality              text,
  whatsapp_number       text,
  created_at            timestamptz not null default timezone('utc', now()),
  avatar_url            text,
  fcm_token             text,
  rating                numeric default 0.0,
  review_count          integer default 0,
  completed_deals_count integer default 0,
  trust_score           integer default 50,
  trust_level           text default 'Seedling'
);

create table public.listings (
  id                   uuid primary key default gen_random_uuid(),
  title                text not null,
  author               text not null,
  price_fcfa           integer not null check (price_fcfa >= 0),
  condition            text not null,
  image_url            text,
  seller_id            uuid not null references public.profiles (id),
  status               text default 'available',
  created_at           timestamptz not null default timezone('utc', now()),
  description          text,
  seller_type          text default 'individual'
                         constraint check_seller_type
                         check (seller_type in ('individual', 'bookshop', 'author')),
  is_buy_back_eligible boolean default false,
  stock_count          integer default 1,
  tsv                  tsvector,
  category             text default 'general',
  is_boosted           boolean default false,
  boost_expires_at     timestamptz,
  expires_at           timestamptz default (now() + interval '60 days'),
  latitude             double precision,
  longitude            double precision
);

create table public.transactions (
  id                uuid primary key default gen_random_uuid(),
  listing_id        uuid not null references public.listings (id) on delete cascade,
  buyer_id          uuid not null references auth.users (id) on delete cascade,
  seller_id         uuid not null references auth.users (id) on delete cascade,
  amount            integer not null check (amount > 0),
  payment_reference text not null unique,
  status            text not null default 'pending'
                      constraint transactions_status_check
                      check (status in ('pending', 'pending_payment', 'successful',
                                        'failed', 'held', 'disputed')),
  created_at        timestamptz default now(),
  payout_status     text default 'pending'
                      check (payout_status in ('pending', 'successful', 'failed')),
  payout_reference  text,
  commission_amount integer default 0
);

create table public.escrow_transactions (
  id               uuid primary key default gen_random_uuid(),
  transaction_id   uuid not null unique references public.transactions (id) on delete cascade,
  status           text not null default 'held'
                     check (status in ('held', 'released', 'refunded', 'disputed')),
  dispute_reason   text,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now(),
  release_deadline timestamptz
);

create table public.fapshi_audit_logs (
  id               uuid primary key default gen_random_uuid(),
  transaction_id   uuid references public.transactions (id) on delete set null,
  endpoint         text not null,
  request_payload  jsonb,
  response_payload jsonb,
  status_code      integer,
  created_at       timestamptz default now()
);

create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid references public.listings (id) on delete cascade,
  sender_id   uuid references public.profiles (id),
  receiver_id uuid references public.profiles (id),
  content     text not null,
  is_read     boolean default false,
  created_at  timestamptz default now()
);
