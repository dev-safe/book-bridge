-- Report and block (Google Play user-generated content policy).
--
-- user_blocks:     a user hides another user's listings and chats. Blocking
--                  also stops new messages in both directions (trigger).
-- content_reports: a user reports a listing or a user. Only admins act on
--                  reports, through the Rust core (connects as postgres).

-- 1. Blocks --------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users (id) on delete cascade,
  blocked_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_id_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

revoke all on public.user_blocks from anon, authenticated;
grant select, insert, delete on public.user_blocks to authenticated;

drop policy if exists "user_blocks_select_own" on public.user_blocks;
create policy "user_blocks_select_own" on public.user_blocks
  for select to authenticated
  using (blocker_id = auth.uid());

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own" on public.user_blocks
  for insert to authenticated
  with check (blocker_id = auth.uid());

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own" on public.user_blocks
  for delete to authenticated
  using (blocker_id = auth.uid());

-- No new messages between two users when either has blocked the other. A
-- trigger works whether or not RLS is enabled on messages and does not
-- interact with its existing policies.
create or replace function public.reject_blocked_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = new.sender_id and b.blocked_id = new.receiver_id)
       or (b.blocker_id = new.receiver_id and b.blocked_id = new.sender_id)
  ) then
    raise exception 'blocked: messages between these users are blocked'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.reject_blocked_message() from public, anon, authenticated;

drop trigger if exists messages_reject_blocked on public.messages;
create trigger messages_reject_blocked
  before insert on public.messages
  for each row execute function public.reject_blocked_message();

-- 2. Reports -------------------------------------------------------------------
-- reporter_id and reported_user_id are cleared when an account is deleted,
-- so neither is NOT NULL. "At least one target" is enforced on insert.
create table if not exists public.content_reports (
  id               uuid primary key default gen_random_uuid(),
  reporter_id      uuid references auth.users (id) on delete set null,
  listing_id       uuid references public.listings (id) on delete set null,
  reported_user_id uuid references auth.users (id) on delete set null,
  reason           text not null check (reason in (
                     'spam', 'scam', 'inappropriate', 'harassment',
                     'prohibited', 'other')),
  details          text check (char_length(details) <= 500),
  status           text not null default 'open'
                     check (status in ('open', 'actioned', 'dismissed')),
  created_at       timestamptz not null default now(),
  reviewed_by      uuid references auth.users (id) on delete set null,
  reviewed_at      timestamptz
);

create index if not exists content_reports_open_idx
  on public.content_reports (created_at)
  where status = 'open';

-- One open report per reporter and target; repeats are no-ops for the app.
create unique index if not exists content_reports_open_once
  on public.content_reports (
    reporter_id,
    coalesce(listing_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(reported_user_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where status = 'open';

alter table public.content_reports enable row level security;

revoke all on public.content_reports from anon, authenticated;
grant insert (listing_id, reported_user_id, reason, details)
  on public.content_reports to authenticated;

drop policy if exists "content_reports_insert_own" on public.content_reports;
create policy "content_reports_insert_own" on public.content_reports
  for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and status = 'open'
    and reviewed_by is null
    and reviewed_at is null
    and num_nonnulls(listing_id, reported_user_id) >= 1
    and reported_user_id is distinct from auth.uid()
  );

-- reporter_id comes from the session, never from the client, and each user
-- may file at most 20 reports a day.
create or replace function public.prepare_content_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.reporter_id := auth.uid();
    if (select count(*) from public.content_reports r
        where r.reporter_id = new.reporter_id
          and r.created_at > now() - interval '1 day') >= 20 then
      raise exception 'report_limit: too many reports today'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.prepare_content_report() from public, anon, authenticated;

drop trigger if exists content_reports_prepare on public.content_reports;
create trigger content_reports_prepare
  before insert on public.content_reports
  for each row execute function public.prepare_content_report();

-- 3. Admin audit trail ---------------------------------------------------------
alter table public.admin_actions
  add column if not exists report_id uuid references public.content_reports (id) on delete set null;

alter table public.admin_actions drop constraint if exists admin_actions_action_check;
alter table public.admin_actions
  add constraint admin_actions_action_check check (action in (
    'release_dispute', 'refund_dispute',
    'refund_unmatched', 'dismiss_unmatched',
    'approve_id', 'reject_id',
    'remove_reported_listing', 'dismiss_report'));
