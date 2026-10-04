-- Multiple listing photos (#32).
--
-- `image_urls` holds up to 3 photos; the first is the cover. `image_url` is
-- kept as the cover so chat, transactions, cards, the offline cache and
-- older APKs keep working unchanged. A trigger keeps the two in sync:
--   * writes that change `image_urls` set `image_url` to its first element;
--   * writes that only change `image_url` (older APKs) replace the cover in
--     `image_urls`, keeping any extra photos.

-- 1. Column + backfill -------------------------------------------------------
alter table public.listings
  add column if not exists image_urls text[] not null default '{}';

update public.listings
set image_urls = array[image_url]
where cardinality(image_urls) = 0
  and coalesce(image_url, '') <> '';

alter table public.listings
  drop constraint if exists listings_image_urls_max_3;
alter table public.listings
  add constraint listings_image_urls_max_3
  check (cardinality(image_urls) <= 3);

-- 2. Keep cover and gallery in sync -----------------------------------------
create or replace function public.sync_listing_cover_image()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.image_urls is not distinct from old.image_urls
     and new.image_url is distinct from old.image_url then
    -- Legacy client replaced only the cover.
    if coalesce(new.image_url, '') = '' then
      new.image_urls := '{}';
    elsif cardinality(new.image_urls) = 0 then
      new.image_urls := array[new.image_url];
    else
      new.image_urls[1] := new.image_url;
    end if;
  elsif cardinality(new.image_urls) > 0 then
    new.image_url := new.image_urls[1];
  elsif coalesce(new.image_url, '') <> '' then
    new.image_urls := array[new.image_url];
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_listing_cover_image on public.listings;
create trigger trg_sync_listing_cover_image
  before insert or update of image_url, image_urls on public.listings
  for each row execute function public.sync_listing_cover_image();

-- 3. Client grants (additive to #60's column lists) --------------------------
grant insert (image_urls), update (image_urls)
  on public.listings to authenticated;
