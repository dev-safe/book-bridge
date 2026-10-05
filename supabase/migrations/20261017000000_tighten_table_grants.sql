-- Defence-in-depth grant tightening (pre-production sweep).
--
-- RLS already blocks these writes, but table-level grants were still the
-- Supabase defaults (ALL). RLS does not apply to TRUNCATE, so remove it and
-- the other privileges clients never need.
--
-- Client usage (lib/):
--   transactions   -> SELECT only (escrow writes go through the Rust core)
--   reviews        -> SELECT + INSERT (authenticated)
--   boost_payments -> unused (Rust core writes as postgres)

-- 1. No client role may TRUNCATE, add triggers, or reference public tables.
do $$
declare
  t record;
begin
  for t in
    select c.oid::regclass as rel
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  loop
    execute format(
      'revoke truncate, references, trigger on %s from anon, authenticated',
      t.rel
    );
  end loop;
end
$$;

alter default privileges for role postgres in schema public
  revoke truncate, references, trigger on tables from anon, authenticated;

-- 2. transactions: read-only for signed-in users, nothing for anon.
revoke all on public.transactions from anon;
revoke insert, update, delete on public.transactions from authenticated;

-- 3. reviews: public read, authenticated insert only.
revoke insert, update, delete on public.reviews from anon;
revoke update, delete on public.reviews from authenticated;

-- 4. boost_payments: owners may read their own rows; no client writes.
revoke all on public.boost_payments from anon;
revoke insert, update, delete on public.boost_payments from authenticated;
