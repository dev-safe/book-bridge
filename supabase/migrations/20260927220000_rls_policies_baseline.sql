-- RLS baseline: snapshot of every row-level security policy enforced in
-- production (project jacnsvcwmhoicuuzmrmr) on 2026-09-27, after the
-- incident fixes in GHSA-xq84-qm9j-hf6p.
--
-- Generated from pg_policies / pg_class in production, not hand-written.
-- Running it against production is a no-op: every policy is dropped and
-- recreated with its current definition. Apply it in one transaction
-- (the Supabase CLI does this per migration) so no table is briefly
-- left without its policies.
--
-- Known weaknesses are reproduced as-is on purpose; each fix gets its own
-- migration so the change is reviewable:
--   * profiles / listings UPDATE policies allow any column
--     (trust_score, rating, boost fields are self-editable)
--   * boost_payments "Anyone can view boosts" is public
--   * donations accepts anonymous inserts
--   * favorites and messages have duplicate policies
--   * storage bucket "books" lets any signed-in user upload anywhere
--
-- From now on, every policy change lands here as a migration first.

-- Removed during the 2026-09-27 incident. Dropped explicitly so replaying
-- older migrations (20260602130000 creates escrow_update_buyer) can never
-- bring them back.
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
drop policy if exists "Buyers can create transactions" on public.transactions;
drop policy if exists escrow_update_buyer on public.escrow_transactions;
drop policy if exists "Read own messages" on public.messages;

alter table public.app_secrets enable row level security;

alter table public.boost_payments enable row level security;

alter table public.campus_zones enable row level security;

alter table public.donations enable row level security;

alter table public.escrow_transactions enable row level security;

alter table public.fapshi_audit_logs enable row level security;

alter table public.favorites enable row level security;

alter table public.feedback enable row level security;

alter table public.impact_metrics enable row level security;

alter table public.listings enable row level security;

alter table public.messages enable row level security;

alter table public.notifications enable row level security;

alter table public.platform_stats enable row level security;

alter table public.profiles enable row level security;

alter table public.reviews enable row level security;

alter table public.transactions enable row level security;

alter table public.wishlists enable row level security;

drop policy if exists "Anyone can view boosts" on public.boost_payments;
create policy "Anyone can view boosts" on public.boost_payments
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Users can create their own boost payments" on public.boost_payments;
create policy "Users can create their own boost payments" on public.boost_payments
  as PERMISSIVE for INSERT to public
  with check ((auth.uid() = user_id));

drop policy if exists "Users can view their own boost payments" on public.boost_payments;
create policy "Users can view their own boost payments" on public.boost_payments
  as PERMISSIVE for SELECT to public
  using ((auth.uid() = user_id));

drop policy if exists "Anyone can read campus zones" on public.campus_zones;
create policy "Anyone can read campus zones" on public.campus_zones
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Anyone can insert anonymous donations" on public.donations;
create policy "Anyone can insert anonymous donations" on public.donations
  as PERMISSIVE for INSERT to public
  with check ((user_id IS NULL));

drop policy if exists "Users can insert their own donations" on public.donations;
create policy "Users can insert their own donations" on public.donations
  as PERMISSIVE for INSERT to authenticated
  with check ((auth.uid() = user_id));

drop policy if exists "Users can view their own donations" on public.donations;
create policy "Users can view their own donations" on public.donations
  as PERMISSIVE for SELECT to authenticated
  using ((auth.uid() = user_id));

drop policy if exists escrow_select_parties on public.escrow_transactions;
create policy escrow_select_parties on public.escrow_transactions
  as PERMISSIVE for SELECT to public
  using ((EXISTS ( SELECT 1
   FROM transactions t
  WHERE ((t.id = escrow_transactions.transaction_id) AND ((t.buyer_id = auth.uid()) OR (t.seller_id = auth.uid()))))));

drop policy if exists "Users can create their own favorites" on public.favorites;
create policy "Users can create their own favorites" on public.favorites
  as PERMISSIVE for INSERT to public
  with check ((auth.uid() = user_id));

drop policy if exists "Users can delete their own favorites" on public.favorites;
create policy "Users can delete their own favorites" on public.favorites
  as PERMISSIVE for DELETE to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can view their own favorites" on public.favorites;
create policy "Users can view their own favorites" on public.favorites
  as PERMISSIVE for SELECT to public
  using ((auth.uid() = user_id));

drop policy if exists favorites_delete_own on public.favorites;
create policy favorites_delete_own on public.favorites
  as PERMISSIVE for DELETE to public
  using ((auth.uid() = user_id));

drop policy if exists favorites_insert_own on public.favorites;
create policy favorites_insert_own on public.favorites
  as PERMISSIVE for INSERT to public
  with check ((auth.uid() = user_id));

drop policy if exists favorites_select_own on public.favorites;
create policy favorites_select_own on public.favorites
  as PERMISSIVE for SELECT to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can insert their own feedback" on public.feedback;
create policy "Users can insert their own feedback" on public.feedback
  as PERMISSIVE for INSERT to authenticated
  with check ((auth.uid() = user_id));

drop policy if exists "Anyone can view impact metrics" on public.impact_metrics;
create policy "Anyone can view impact metrics" on public.impact_metrics
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Listings are viewable by everyone." on public.listings;
create policy "Listings are viewable by everyone." on public.listings
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Users can delete their own listings." on public.listings;
create policy "Users can delete their own listings." on public.listings
  as PERMISSIVE for DELETE to public
  using ((auth.uid() = seller_id));

drop policy if exists "Users can insert their own listings." on public.listings;
create policy "Users can insert their own listings." on public.listings
  as PERMISSIVE for INSERT to public
  with check ((auth.uid() = seller_id));

drop policy if exists "Users can update their own listings." on public.listings;
create policy "Users can update their own listings." on public.listings
  as PERMISSIVE for UPDATE to public
  using ((auth.uid() = seller_id));

drop policy if exists "Insert own messages" on public.messages;
create policy "Insert own messages" on public.messages
  as PERMISSIVE for INSERT to public
  with check ((sender_id = auth.uid()));

drop policy if exists "Users can insert their own messages" on public.messages;
create policy "Users can insert their own messages" on public.messages
  as PERMISSIVE for INSERT to authenticated
  with check ((auth.uid() = sender_id));

drop policy if exists "Users can mark messages as read (receiver only)" on public.messages;
create policy "Users can mark messages as read (receiver only)" on public.messages
  as PERMISSIVE for UPDATE to authenticated
  using ((auth.uid() = receiver_id))
  with check ((auth.uid() = receiver_id));

drop policy if exists "Users can read their own messages" on public.messages;
create policy "Users can read their own messages" on public.messages
  as PERMISSIVE for SELECT to authenticated
  using (((auth.uid() = sender_id) OR (auth.uid() = receiver_id)));

drop policy if exists "Users can update their own notifications" on public.notifications;
create policy "Users can update their own notifications" on public.notifications
  as PERMISSIVE for UPDATE to authenticated
  using ((auth.uid() = user_id));

drop policy if exists "Users can view their own notifications" on public.notifications;
create policy "Users can view their own notifications" on public.notifications
  as PERMISSIVE for SELECT to authenticated
  using ((auth.uid() = user_id));

drop policy if exists "Anyone can view platform stats" on public.platform_stats;
create policy "Anyone can view platform stats" on public.platform_stats
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles
  as PERMISSIVE for UPDATE to public
  using ((auth.uid() = id));

drop policy if exists "Users can view own profile." on public.profiles;
create policy "Users can view own profile." on public.profiles
  as PERMISSIVE for SELECT to authenticated
  using ((auth.uid() = id));

drop policy if exists "Anyone can read reviews" on public.reviews;
create policy "Anyone can read reviews" on public.reviews
  as PERMISSIVE for SELECT to public
  using (true);

drop policy if exists "Only verified buyers can create reviews" on public.reviews;
create policy "Only verified buyers can create reviews" on public.reviews
  as PERMISSIVE for INSERT to public
  with check (((auth.uid() = reviewer_id) AND (EXISTS ( SELECT 1
   FROM transactions
  WHERE ((transactions.buyer_id = auth.uid()) AND (transactions.seller_id = reviews.reviewee_id) AND (transactions.status = 'successful'::text))))));

drop policy if exists "Users can view their own transactions" on public.transactions;
create policy "Users can view their own transactions" on public.transactions
  as PERMISSIVE for SELECT to authenticated
  using (((auth.uid() = buyer_id) OR (auth.uid() = seller_id)));

drop policy if exists wishlists_delete_own on public.wishlists;
create policy wishlists_delete_own on public.wishlists
  as PERMISSIVE for DELETE to public
  using ((auth.uid() = user_id));

drop policy if exists wishlists_insert_own on public.wishlists;
create policy wishlists_insert_own on public.wishlists
  as PERMISSIVE for INSERT to public
  with check ((auth.uid() = user_id));

drop policy if exists wishlists_select_own on public.wishlists;
create policy wishlists_select_own on public.wishlists
  as PERMISSIVE for SELECT to public
  using ((auth.uid() = user_id));

drop policy if exists "Allow authenticated users to delete own book images" on storage.objects;
create policy "Allow authenticated users to delete own book images" on storage.objects
  as PERMISSIVE for DELETE to public
  using (((bucket_id = 'book_images'::text) AND (auth.uid() = ((storage.foldername(name))[1])::uuid)));

drop policy if exists "Allow authenticated users to delete profile pictures" on storage.objects;
create policy "Allow authenticated users to delete profile pictures" on storage.objects
  as PERMISSIVE for DELETE to public
  using (((bucket_id = 'profiles'::text) AND (auth.uid() = ((storage.foldername(name))[1])::uuid)));

drop policy if exists "Allow authenticated users to update profile pictures" on storage.objects;
create policy "Allow authenticated users to update profile pictures" on storage.objects
  as PERMISSIVE for UPDATE to public
  using (((bucket_id = 'profiles'::text) AND (auth.uid() = ((storage.foldername(name))[1])::uuid)));

drop policy if exists "Allow authenticated users to upload book images" on storage.objects;
create policy "Allow authenticated users to upload book images" on storage.objects
  as PERMISSIVE for INSERT to public
  with check (((bucket_id = 'book_images'::text) AND (auth.uid() = ((storage.foldername(name))[1])::uuid)));

drop policy if exists "Allow authenticated users to upload profile pictures" on storage.objects;
create policy "Allow authenticated users to upload profile pictures" on storage.objects
  as PERMISSIVE for INSERT to public
  with check (((bucket_id = 'profiles'::text) AND (auth.uid() = ((storage.foldername(name))[1])::uuid)));

drop policy if exists "Allow public access to view book images" on storage.objects;
create policy "Allow public access to view book images" on storage.objects
  as PERMISSIVE for SELECT to public
  using ((bucket_id = 'book_images'::text));

drop policy if exists "Allow public access to view profile pictures" on storage.objects;
create policy "Allow public access to view profile pictures" on storage.objects
  as PERMISSIVE for SELECT to public
  using ((bucket_id = 'profiles'::text));

drop policy if exists "Book images are publicly accessible." on storage.objects;
create policy "Book images are publicly accessible." on storage.objects
  as PERMISSIVE for SELECT to public
  using ((bucket_id = 'books'::text));

drop policy if exists "Users can upload book images." on storage.objects;
create policy "Users can upload book images." on storage.objects
  as PERMISSIVE for INSERT to public
  with check (((bucket_id = 'books'::text) AND (auth.role() = 'authenticated'::text)));
