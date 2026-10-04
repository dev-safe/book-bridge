-- Seller-chosen meetup spots (#33).
--
-- Phones aren't allowed in most secondary schools, so instead of fixed
-- school zones the seller names a public meetup spot (e.g. "Molyko
-- roundabout") and may drop an optional pin. The client rounds the pin to
-- ~100 m before saving. `campus_zones` stays as quick suggestions only.

-- 1. Columns -----------------------------------------------------------------
alter table public.listings
  add column if not exists meetup_spot text,
  add column if not exists meetup_latitude double precision,
  add column if not exists meetup_longitude double precision;

alter table public.listings
  drop constraint if exists listings_meetup_spot_length;
alter table public.listings
  add constraint listings_meetup_spot_length
  check (meetup_spot is null or char_length(btrim(meetup_spot)) between 1 and 80);

alter table public.listings
  drop constraint if exists listings_meetup_coords_valid;
alter table public.listings
  add constraint listings_meetup_coords_valid
  check (
    (meetup_latitude is null and meetup_longitude is null)
    or (
      meetup_latitude is not null
      and meetup_longitude is not null
      and meetup_latitude between -90 and 90
      and meetup_longitude between -180 and 180
    )
  );

-- 2. Client grants (additive to #60's column lists) --------------------------
grant insert (meetup_spot, meetup_latitude, meetup_longitude),
  update (meetup_spot, meetup_latitude, meetup_longitude)
  on public.listings to authenticated;
