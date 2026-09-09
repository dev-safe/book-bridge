# Antigravity Build Prompt — BookBridge Rust Migration (Phase 1)

## Read this first: the golden rule for this task

This is a **language port, not a redesign**. `process-escrow` and `fapshi-polling` are live, tested Deno Edge Functions currently moving real money for real students. Your job is to reproduce their exact business logic — state transitions, query conditions, edge cases — in Rust/Axum. Do not infer, simplify, or "improve" the logic based on this prompt alone.

Before writing any handler:
1. Locate the current source: `supabase/functions/process-escrow/index.ts` and `supabase/functions/fapshi-polling/index.ts`
2. Read them fully
3. Port them faithfully — same conditions, same state transitions, same audit logging
4. Only the following are allowed to differ from the original: language (TS→Rust), framework (Deno→Axum), the new internal-auth layer, the new `/health` route, Rust-idiomatic error handling

If anything in the existing source is ambiguous or seems to contradict this prompt, flag it and ask — do not guess at business logic involving money.

---

## Context

BookBridge is a peer-to-peer textbook marketplace for Cameroonian students — Flutter mobile app, SvelteKit landing/web, Supabase Postgres backend, Fapshi mobile money for payments. Live at v1.5.0. This is Phase 1 of a planned 4-phase migration from Supabase Deno Edge Functions to a standalone Rust/Axum service. Supabase Postgres remains the permanent source of truth — nothing about the schema changes in this phase.

## Objective

Stand up a new Rust/Axum service, `bookbridge-rust-core`, replacing two existing Edge Functions:
1. `process-escrow` — coordinates seller payouts for expired escrow holds
2. `fapshi-polling` — polls Fapshi for payment status on transactions stuck in `pending_payment`

## Explicitly out of scope for this milestone

- **The SvelteKit Fapshi webhook handler** (`src/routes/api/webhooks/fapshi/+server.js`) — this is Phase 2, deliberately deferred. It's the highest-risk piece since it receives inbound calls from Fapshi directly.
- **The Power Seller subscription payment confirmation** — this is a small addition to the *existing* SvelteKit webhook handler (a new branch for subscription-type Fapshi callbacks), not new Rust code. Do not build a Rust webhook receiver for this in this milestone.
- AI inference / book cover classification — Phase 3.
- Any change to Supabase Auth — Phase 4, optional, not now.
- Any change to the Flutter app — none needed for this milestone.
- Any change to the *structure* of `escrow_transactions`, `fapshi_audit_logs`, or other existing tables — this service only inserts/updates rows, it never alters columns.

## Architecture

```
pg_cron (Supabase, timing unchanged: hourly + every 5 min)
   │  net.http_post + X-Internal-Secret header
   ▼
Axum service (new — bookbridge-rust-core, hosted on Render free tier)
   │  sqlx, direct Postgres connection
   ▼
Supabase Postgres (schema unchanged)
   │  reqwest
   ▼
Fapshi API (unchanged)
```

---

## Endpoints to build

### 1. `POST /internal/escrow/process-releases`
Replaces `process-escrow`. Triggered by the existing `auto-release-escrows-job` pg_cron job (hourly).
- Require and validate an `X-Internal-Secret` header using **constant-time comparison** — never a plain `==` on the raw strings, since that leaks timing information.
- Port the exact query and payout logic from the current Edge Function.
- Every Fapshi API call must insert a row into `fapshi_audit_logs` (endpoint, payload, status code) exactly as the current function does.
- Return a typed JSON response, e.g. `{ "processed": u32, "released": u32, "failed": u32 }`.
- On any individual payout failure: do NOT mark that transaction released. Leave it for the next run and log the failure clearly. Never silently swallow a failed payout.

### 2. `POST /internal/escrow/poll-pending`
Replaces `fapshi-polling`. Triggered by the existing `fapshi-polling-job` pg_cron job (every 5 minutes).
- Same internal auth as above.
- Port the exact query and status-check logic for transactions stuck in `pending_payment`.
- Same audit-logging requirement.
- Typed JSON response summarizing what was checked and what changed.

### 3. `GET /health`
- No auth required.
- Returns `200 OK` with a trivial JSON body.
- Exists so a GitHub Actions scheduled workflow can ping it every 10 minutes and keep the Render free-tier instance warm.

---

## Internal auth (new — this doesn't exist in the current Deno functions)

Both `/internal/*` routes trigger real payouts and will be reachable over the public internet once deployed, so they need protecting:
- Generate a random secret (e.g. `openssl rand -hex 32`). Store it as a Supabase Vault secret (you already use Vault for other secrets, per the existing commit history) and as a Render environment variable, `INTERNAL_API_SECRET`.
- Axum middleware checks the `X-Internal-Secret` header against it using the `subtle` crate's `ConstantTimeEq` (or an equivalent manual constant-time compare).
- Missing or invalid header → `401 Unauthorized`, logged.

---

## Suggested project structure

```
bookbridge-rust-core/
├── Cargo.toml
├── .env.example
├── src/
│   ├── main.rs
│   ├── config.rs        # env var loading
│   ├── db.rs             # sqlx::PgPool setup
│   ├── auth.rs           # internal-secret middleware
│   ├── fapshi.rs         # Fapshi API client (reqwest)
│   ├── error.rs          # typed error enum + IntoResponse impl
│   └── routes/
│       ├── mod.rs
│       ├── escrow.rs      # both /internal/escrow/* handlers
│       └── health.rs
└── tests/
    ├── auth_tests.rs
    └── escrow_tests.rs
```

## Suggested dependencies

`axum`, `tokio` (full features), `sqlx` (postgres, runtime-tokio-rustls, macros), `serde` / `serde_json`, `reqwest` (json feature), `tracing` + `tracing-subscriber`, `dotenvy`, `thiserror`, `subtle`, `uuid`.

---

## Testing requirements

- Unit tests for the auth middleware: valid secret, invalid secret, missing header.
- Tests for the escrow-release query logic against a test database (sqlx supports test fixtures/transactions for this).
- If Fapshi sandbox credentials aren't available to test real API calls end-to-end, mock the HTTP client and clearly state in the PR description what wasn't tested against the live API — don't skip this silently.

---

## Deployment

- Target: Render free tier, Web Service (native Rust runtime if it detects `Cargo.toml` cleanly, Dockerfile otherwise).
- Environment variables: `DATABASE_URL` (Supabase connection string), `FAPSHI_API_KEY`, `INTERNAL_API_SECRET`.
- After deploy, add `.github/workflows/keep-warm.yml` — a scheduled workflow pinging `/health` every 10 minutes to prevent Render's 15-minute cold-start spin-down.

---

## Cutover plan (manual, do this last — not part of the Rust code itself)

1. Deploy to Render, confirm `/health` responds.
2. Manually trigger both `/internal/*` endpoints against a test transaction and verify the behavior matches the old Edge Functions exactly.
3. Only then, update the pg_cron job definitions in Supabase to point at the new Render URLs, with the secret header attached:

```sql
-- Run manually in the Supabase SQL editor once the Render URL is known —
-- do not run until step 2 above is verified.
select cron.alter_job(
  job_id := (select jobid from cron.job where jobname = 'auto-release-escrows-job'),
  command := $$
    select net.http_post(
      url := 'https://<your-render-url>/internal/escrow/process-releases',
      headers := jsonb_build_object(
        'X-Internal-Secret',
        (select decrypted_secret from vault.decrypted_secrets where name = 'internal_api_secret')
      )
    );
  $$
);
-- Repeat for 'fapshi-polling-job' targeting /internal/escrow/poll-pending
```

4. Keep the old Deno functions in the repo (just undeployed from cron) for a rollback window before deleting them.

---

## Deliverables checklist

- [ ] `bookbridge-rust-core` with the structure above
- [ ] Both `/internal/*` endpoints, faithfully ported from the existing Deno source
- [ ] `/health` endpoint
- [ ] Internal auth middleware with constant-time comparison
- [ ] Tests per the section above
- [ ] `.env.example` documenting required variables
- [ ] Render deployment live, `/health` verified
- [ ] GitHub Actions keep-warm workflow
- [ ] The pg_cron cutover SQL above, ready to run manually — not auto-executed by Antigravity
