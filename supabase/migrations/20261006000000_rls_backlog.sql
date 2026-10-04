-- RLS and grant hardening backlog (#60).
--
-- 1. public_profiles: a safe, column-explicit view for cross-user reads
--    (seller cards, chat headers). profiles itself stays owner-only.
-- 2. Column-level INSERT/UPDATE grants so clients can no longer write
--    trust/rating/boost/status fields, plus WITH CHECK on UPDATE policies.
-- 3. Drop public SELECT on boost_payments.
-- 4. Revoke client EXECUTE on SECURITY DEFINER / internal functions.
-- 5. Remove the duplicate delete_old_messages cron job.
-- 6. Drop the unchecked "books" bucket upload policy (bucket unused).
-- 7. Revoke client access to app_secrets and fapshi_audit_logs.
-- 8. Remove duplicate favorites/messages policies.
--
-- Server-side writers (Rust core as postgres, landing page as service_role,
-- SECURITY DEFINER triggers) are unaffected by these client grants.

-- 1. public_profiles ---------------------------------------------------------
-- Owned by postgres and not security_invoker, so it reads profiles without
-- the owner-only RLS policy. Only the columns below are ever exposed.
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
  created_at
from public.profiles;

revoke all on public.public_profiles from public, anon, authenticated;
grant select on public.public_profiles to anon, authenticated;

-- 2a. profiles: owner may only edit their own display fields ----------------
-- whatsapp_number / fcm_token stay writable for older APKs; the #54 sync
-- trigger copies them into profiles_private.
revoke insert, update on public.profiles from anon, authenticated;
grant update (full_name, locality, avatar_url, whatsapp_number, fcm_token)
  on public.profiles to authenticated;

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 2b. listings: no client writes to status, boost or expiry fields ----------
revoke insert, update on public.listings from anon, authenticated;
grant insert (
  title, author, price_fcfa, condition, image_url, description, category,
  seller_id, status, created_at, seller_type, is_buy_back_eligible,
  stock_count, latitude, longitude
) on public.listings to authenticated;
grant update (
  title, author, price_fcfa, condition, image_url, description, category,
  seller_type, is_buy_back_eligible, stock_count, latitude, longitude
) on public.listings to authenticated;

drop policy if exists "Users can insert their own listings." on public.listings;
create policy "Users can insert their own listings." on public.listings
  for insert to authenticated
  with check (auth.uid() = seller_id and coalesce(status, 'available') = 'available');

drop policy if exists "Users can update their own listings." on public.listings;
create policy "Users can update their own listings." on public.listings
  for update to authenticated
  using (auth.uid() = seller_id)
  with check (auth.uid() = seller_id);

drop policy if exists "Users can delete their own listings." on public.listings;
create policy "Users can delete their own listings." on public.listings
  for delete to authenticated
  using (auth.uid() = seller_id);

-- 3. boost_payments: owners keep their own SELECT policy --------------------
do $$
begin
  if to_regclass('public.boost_payments') is not null then
    drop policy if exists "Anyone can view boosts" on public.boost_payments;
  end if;
end $$;

-- 4. Internal functions are not client-callable ------------------------------
-- Triggers and pg_cron do not need the caller to hold EXECUTE.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.handle_new_user()',
    'public.handle_new_user_welcome_notification()',
    'public.notify_impact_milestone_fcm()',
    'public.notify_new_inquiry()',
    'public.notify_payment_confirmed()',
    'public.on_review_change_trigger()',
    'public.on_transaction_change_trigger()',
    'public.recalculate_all_seller_stats()',
    'public.recalculate_platform_stats()',
    'public.recalculate_seller_stats(uuid)',
    'public.update_platform_impact_metrics()',
    'public.delete_old_messages()',
    'public.sync_profiles_private()'
  ]
  loop
    if to_regprocedure(fn) is not null then
      execute format('revoke execute on function %s from public, anon, authenticated', fn);
    end if;
  end loop;
end $$;

-- 5. Duplicate cron job ------------------------------------------------------
-- Supabase forbids direct DML on cron.job; use cron.unschedule instead.
do $$
declare
  dup bigint;
begin
  if to_regclass('cron.job') is not null then
    for dup in
      select jobid from cron.job
      where command ilike '%delete_old_messages()%'
        and jobid > (
          select min(jobid) from cron.job where command ilike '%delete_old_messages()%'
        )
    loop
      begin
        perform cron.unschedule(dup);
      exception when others then
        raise notice 'Could not unschedule duplicate cron job %: %', dup, sqlerrm;
      end;
    end loop;
  end if;
end $$;

-- 6. Unused "books" bucket: no unchecked uploads ------------------------------
do $$
begin
  if to_regclass('storage.objects') is not null then
    drop policy if exists "Users can upload book images." on storage.objects;
  end if;
end $$;

-- 7. Server-only tables -------------------------------------------------------
revoke all on public.app_secrets from anon, authenticated;
revoke all on public.fapshi_audit_logs from anon, authenticated;

-- 8. Duplicate policies ---------------------------------------------------------
do $$
begin
  if to_regclass('public.favorites') is not null then
    drop policy if exists "Users can create their own favorites" on public.favorites;
    drop policy if exists "Users can delete their own favorites" on public.favorites;
    drop policy if exists "Users can view their own favorites" on public.favorites;
  end if;
end $$;

drop policy if exists "Insert own messages" on public.messages;
