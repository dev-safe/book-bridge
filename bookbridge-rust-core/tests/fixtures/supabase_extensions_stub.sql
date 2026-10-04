-- Local stand-ins for the Supabase pieces that production_schema.sql leaves
-- out but 20261008000000_push_notifications.sql needs: the notifications table
-- (production columns and RLS), Vault, pg_net and pg_cron. Load it after
-- production_schema.sql and before the migrations. net.http_post only records
-- each call in net._calls so tests can assert on it; nothing leaves the box.
-- Never load this into a real Supabase project.

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  title      text not null,
  body       text not null,
  type       text not null default 'general',
  is_read    boolean not null default false,
  data       jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "Users can view their own notifications" on public.notifications
  for select to authenticated using (auth.uid() = user_id);

create policy "Users can update their own notifications" on public.notifications
  for update to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.notifications to anon, authenticated;

create schema if not exists vault;

create table vault.secrets (
  id     uuid primary key default gen_random_uuid(),
  name   text unique not null,
  secret text not null
);

create view vault.decrypted_secrets as
  select id, name, secret as decrypted_secret from vault.secrets;

insert into vault.secrets (name, secret) values ('internal_api_secret', 'local-test-secret');

create schema if not exists net;

create table net._calls (
  id      bigserial primary key,
  url     text not null,
  headers jsonb,
  body    jsonb,
  at      timestamptz not null default now()
);

create function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type": "application/json"}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint
language sql
as $$
  insert into net._calls (url, headers, body) values (url, headers, body) returning id;
$$;

create schema if not exists cron;

create table cron.job (
  jobid    bigserial primary key,
  jobname  text unique,
  schedule text not null,
  command  text not null
);

create function cron.schedule(job_name text, schedule text, command text)
returns bigint
language sql
as $$
  insert into cron.job (jobname, schedule, command) values (job_name, schedule, command)
  on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command
  returning jobid;
$$;

create function cron.unschedule(job_name text)
returns boolean
language sql
as $$
  with d as (delete from cron.job where jobname = job_name returning 1)
  select exists (select 1 from d);
$$;

create function cron.unschedule(job_id bigint)
returns boolean
language sql
as $$
  with d as (delete from cron.job where jobid = job_id returning 1)
  select exists (select 1 from d);
$$;
