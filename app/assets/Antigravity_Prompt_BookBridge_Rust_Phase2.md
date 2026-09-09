# Antigravity Build Prompt — BookBridge Rust Migration (Phase 2)

## Read this first: same golden rule as Phase 1, higher stakes this time

Phase 1 ported internal, self-triggered logic (cron calling your own endpoints). Phase 2 is different in kind: **Fapshi calls you, from the public internet, to confirm that real money changed hands.** This is the highest-risk piece in the whole migration, and it's why it was deliberately deferred until Phase 1 was solid.

Before writing anything:
1. Locate and read the current `src/routes/api/webhooks/fapshi/+server.js` in full.
2. Port its branching logic faithfully — every event type it handles, every table it touches, every edge case. Do not redesign based on this prompt's description alone.
3. If anything in the existing source contradicts this prompt, flag it — don't guess at logic that decides whether a seller gets marked paid.

---

## Context

Phase 1 shipped `bookbridge-rust-core` on Render, handling `process-escrow` and `fapshi-polling`. Both of those are *outbound*-triggered (your cron calling out). This milestone adds the one *inbound* endpoint: Fapshi's webhook, which currently lives in SvelteKit and is the primary, fast path for confirming a payment — `fapshi-polling` is its fallback for when the webhook doesn't arrive within 10 minutes.

That relationship matters architecturally: **both paths can end up trying to process the same transaction.** Whichever gets there first must win, and the other must safely no-op — not double-process, not double-send the buyer/seller chat message, not corrupt state.

## Objective

Add a new route to the existing `bookbridge-rust-core` service — not a new service — that replaces the SvelteKit Fapshi webhook handler.

## Fapshi's actual webhook mechanism (confirmed, not HMAC)

Fapshi doesn't sign webhooks cryptographically. It sends back a static secret, configured on your Fapshi dashboard, verbatim in an `x-wh-secret` header on every call. Verification is a direct constant-time comparison — architecturally identical to the `X-Internal-Secret` middleware already built in Phase 1. Reuse that same constant-time comparison utility; don't write a second one.

Webhook fires on three status changes: `SUCCESSFUL`, `FAILED`, `EXPIRED` (a payment link that timed out after 24h unpaid). Payload includes `transId`, `externalId`, `amount`, `status`, and related fields — confirm exact field names against the current SvelteKit handler rather than this list, since that's the ground truth.

## Endpoint

### `POST /webhooks/fapshi`

- **Public** — no `X-Internal-Secret` (that's for pg_cron only). Auth here is the `x-wh-secret` header check described above, against a secret stored consistently with how Phase 1 stores Fapshi credentials (`app_secrets`, or wherever the current handler reads it from — check and match, don't invent a new location).
- **Must not panic on malformed input.** This route is reachable by anyone on the internet, not just Fapshi. Validate and reject cleanly (`400`) rather than unwrapping into a crash. Phase 1's routes never had to think about hostile input; this one does.
- **Race-safe claim before acting.** Before performing any side effects, atomically claim the transaction with a conditional update, e.g.:
  ```sql
  UPDATE transactions SET status = 'held' WHERE id = $1 AND status = 'pending_payment'
  ```
  Check rows-affected. If zero rows were updated, the transaction was already handled (either by `fapshi-polling` beating you to it, or by Fapshi re-delivering the same webhook — both are real and expected) — return `200` and do nothing further. Only proceed to the escrow upsert and chat-message insert if you actually won the claim.
- **On `SUCCESSFUL`:** same downstream effects as `poll_pending_handler`'s success branch from Phase 1 (mark `listings.status = 'sold'`, upsert `escrow_transactions` to `held`, insert the opening chat message). Extract this into a shared function both handlers call — don't duplicate the logic; that's exactly the kind of drift that causes the two paths to quietly diverge later.
- **On `FAILED` / `EXPIRED`:** same as `poll_pending_handler`'s failure branch.
- **Audit logging:** log to `fapshi_audit_logs` as before, but — this is a direct lesson from Phase 1's review — **an audit-log write failure must never block the actual status transition.** Log the logging failure and move on; don't let it propagate as an error that aborts a successful payment confirmation.
- **Respond fast.** Fapshi very likely retries on non-2xx or timeout (standard webhook behavior) — that's a feature, not a problem, given the race-safe claim above, but don't add unnecessary synchronous work that risks a slow response.

## Testing requirements (same isolation discipline as Phase 1 — this bit)

- Auth: valid secret, invalid secret, missing header.
- Malformed payload: confirm `400`, not a panic.
- **Duplicate delivery:** call the endpoint twice with the same `SUCCESSFUL` payload. Assert the second call is a no-op (zero rows updated, no duplicate chat message).
- **Race with poll-pending:** simulate both paths attempting to claim the same transaction; assert exactly one succeeds and the other observes zero rows affected.
- Commit test fixtures to the database before invoking the handler under test — Phase 1's tests initially didn't do this and produced false passes. Don't repeat that.

## Cutover plan (lower code risk than Phase 1, different mechanism)

This cutover isn't a pg_cron URL change — it's changing the webhook URL configured on Fapshi's side (dashboard or their webhook-config API endpoint).

1. Deploy the new route on the existing Render service, verify it manually against Fapshi's sandbox first.
2. Only after that: update the webhook URL in Fapshi's configuration to point at the new `/webhooks/fapshi` route.
3. Leave the SvelteKit handler's code in place (just no longer receiving traffic) as an instant rollback — reverting is just pointing the webhook URL back, no redeploy needed.
4. Watch `fapshi_audit_logs` and the CI-gated test suite closely for the first real traffic before removing the SvelteKit code.

## Deliverables checklist

- [ ] `POST /webhooks/fapshi` added to the existing service, ported faithfully from the current SvelteKit handler
- [ ] `x-wh-secret` constant-time auth, reusing Phase 1's comparison utility
- [ ] Race-safe conditional claim before any side effect
- [ ] Shared success/failure logic between this route and `poll_pending_handler` (no duplicated business logic)
- [ ] Audit log failures logged, never propagated as blocking errors
- [ ] Malformed-input handling that returns 400, never panics
- [ ] Tests: auth, malformed input, duplicate delivery, race with poll-pending
- [ ] Fapshi sandbox verification before touching the real webhook URL
- [ ] CI green on this PR before merge — non-negotiable given what shipped without it earlier in this project
