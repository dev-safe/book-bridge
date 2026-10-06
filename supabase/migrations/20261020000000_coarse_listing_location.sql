-- Coarse listing locations.
--
-- The app saves the seller's GPS position with each listing and shows it as a
-- map pin to every user. That exposed sellers' precise (often home) location.
-- Round listing coordinates to 2 decimals (about 1.1 km): still enough for
-- "nearest books" sorting and the map, but no longer a precise location.
--
-- Meetup pins (meetup_latitude/longitude) are public spots the seller picks
-- on purpose, already rounded by the app, so they are left unchanged.
--
-- Idempotent: safe to run more than once.

create or replace function public.coarsen_listing_location()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.latitude := round(new.latitude::numeric, 2)::double precision;
  new.longitude := round(new.longitude::numeric, 2)::double precision;
  return new;
end;
$$;

drop trigger if exists trg_coarsen_listing_location on public.listings;
create trigger trg_coarsen_listing_location
  before insert or update of latitude, longitude on public.listings
  for each row execute function public.coarsen_listing_location();

-- Round existing listings (the trigger above does the rounding).
update public.listings
set latitude = latitude,
    longitude = longitude
where latitude is distinct from round(latitude::numeric, 2)::double precision
   or longitude is distinct from round(longitude::numeric, 2)::double precision;
