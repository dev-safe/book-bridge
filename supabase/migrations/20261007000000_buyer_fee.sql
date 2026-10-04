-- Buyer pays a 6% service fee on top; the seller receives the full price (#30).
--
-- transactions.amount stays the book price, so seller stats, impact metrics
-- and notifications are unchanged. buyer_fee is what the buyer paid on top
-- (Fapshi charge = amount + buyer_fee). Rows created before this change keep
-- buyer_fee = 0 and their stored 5% commission_amount, so they still pay out
-- at 95% on release.
alter table public.transactions
  add column if not exists buyer_fee integer not null default 0
  constraint transactions_buyer_fee_nonnegative check (buyer_fee >= 0);

comment on column public.transactions.buyer_fee is
  'Service fee (XAF) the buyer paid on top of amount. 0 for pre-#30 rows.';
