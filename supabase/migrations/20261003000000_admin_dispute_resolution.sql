-- Admin dispute resolution (#51).
--
-- Every table here is server-only: RLS is on with no policies, and anon /
-- authenticated lose their default grants, so only the Rust service
-- (connecting as postgres) can read or write them.

-- Who may resolve disputes. Rows are added by hand in the SQL editor:
--   insert into public.admin_users (user_id) values ('<auth user uuid>');
create table if not exists public.admin_users (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- The Mobile Money number each collection was paid from, recorded at
-- checkout so a refund goes back to the payer. Keyed by Fapshi's transId,
-- which is transactions.payment_reference for purchases.
create table if not exists public.payment_payers (
  payment_reference text primary key,
  phone             text not null,
  created_at        timestamptz not null default now()
);

-- One row per admin decision. A refund's Fapshi payout id goes in
-- payout_reference; transactions.payout_reference stays the seller payout.
create table if not exists public.admin_actions (
  id               uuid primary key default gen_random_uuid(),
  admin_id         uuid not null references auth.users (id),
  action           text not null check (action in (
                     'release_dispute', 'refund_dispute',
                     'refund_unmatched', 'dismiss_unmatched')),
  transaction_id   uuid references public.transactions (id) on delete set null,
  audit_log_id     uuid references public.fapshi_audit_logs (id) on delete set null,
  payout_reference text,
  note             text not null check (char_length(note) between 1 and 1000),
  created_at       timestamptz not null default now(),
  check (num_nonnulls(transaction_id, audit_log_id) <= 1)
);

-- An unmatched payment is resolved at most once.
create unique index if not exists admin_actions_unmatched_once
  on public.admin_actions (audit_log_id)
  where audit_log_id is not null;

create index if not exists admin_actions_transaction_id_idx
  on public.admin_actions (transaction_id);

alter table public.admin_users     enable row level security;
alter table public.payment_payers  enable row level security;
alter table public.admin_actions   enable row level security;

revoke all on public.admin_users    from anon, authenticated;
revoke all on public.payment_payers from anon, authenticated;
revoke all on public.admin_actions  from anon, authenticated;

-- A refunded purchase needs its own status: it is neither a failed payment
-- nor a successful sale. Keeps every value production already allows.
alter table public.transactions drop constraint if exists transactions_status_check;
alter table public.transactions add constraint transactions_status_check
  check (status in (
    'pending', 'pending_payment', 'successful', 'failed',
    'held', 'disputed', 'refunded'));
