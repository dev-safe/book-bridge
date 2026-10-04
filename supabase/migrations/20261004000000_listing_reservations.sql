-- Double-sell guard (#52).
--
-- A buyer holds a short reservation on a listing while their Mobile Money
-- payment is in flight, so a second buyer can't start paying for the same
-- book. /payments/initiate takes the reservation atomically; it is released
-- when the payment fails or expires, or deleted when the purchase succeeds.
-- A reservation past reserved_until can be taken over by another buyer.
--
-- Server-only: RLS is on with no policies, and anon / authenticated lose
-- their default grants, so buyer ids are never exposed to other users.
create table if not exists public.listing_reservations (
  listing_id     uuid primary key references public.listings (id) on delete cascade,
  buyer_id       uuid not null references auth.users (id) on delete cascade,
  reserved_until timestamptz not null,
  created_at     timestamptz not null default now()
);

alter table public.listing_reservations enable row level security;

revoke all on public.listing_reservations from anon, authenticated;
