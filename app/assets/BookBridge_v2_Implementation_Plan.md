# BookBridge v2.0 — Implementation Plan
*Rust/Axum migration + Power Seller subscription tier*
*July 2026*

---

## 1. One clarification first: Axum, Railway, and Render are not alternatives to each other

They solve different problems, so this isn't a three-way choice:

| Term | What it is | Layer |
|---|---|---|
| **Axum** | The Rust *web framework* you write your API code in (routes, handlers, middleware) | Code |
| **Railway** | A hosting platform that *runs* your compiled Axum service | Infrastructure |
| **Render** | A competing hosting platform that also *runs* your compiled Axum service | Infrastructure |

So the real decision is two separate ones: (a) which Rust framework, (b) where does the compiled binary live. Answered below.

---

## 2. Stack responsibility matrix

This is the "which language/framework is best at what" breakdown, reflecting where things stand today plus what v2.0 adds:

| Layer | Tech | Owns | Does NOT touch |
|---|---|---|---|
| **Mobile app** | Flutter/Dart | All UI, offline sqflite cache, push notifications, in-app chat | Payment processing logic, escrow rules |
| **Landing/Web** | SvelteKit | Marketing site, Founder page, **new: Power Seller subscription checkout** | Mobile app state |
| **Business logic** | Rust/Axum (new) | Escrow orchestration, Fapshi webhook validation, fraud checks, subscription tier enforcement, AI inference | Long-term data storage |
| **Data layer** | Supabase (Postgres) | Source of truth for all data, RLS, Auth, Realtime, Storage — **unchanged forever** per the existing migration plan | Business rules (these move to Rust over time) |
| **Payments** | Fapshi | All money movement — escrow holds, payouts, **and now subscription payments** | App logic |

This matches and extends the Rust Backend Rewrite Plan already in your Master Context doc — nothing here contradicts it, it just slots the subscription work into the existing phases.

---

## 3. What v2.0 actually adds (recap)

From our discussion: a **hybrid model**, not a replacement of escrow.

- Free tier: 3 active listings per account (not 1 — stays competitive with Facebook Marketplace at the top of the funnel)
- Power Seller subscription: ~500 FCFA/month → unlimited listings + boosted search placement
- Escrow (5% commission, 5-day auto-release) stays exactly as-is — it's still your core revenue engine *and* your actual differentiator from Facebook

---

## 4. Data model additions (Supabase Postgres — unchanged tech, new tables)

```sql
-- Track subscription state per user
create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  tier text not null check (tier in ('free', 'power_seller')),
  status text not null check (status in ('active', 'expired', 'cancelled')),
  fapshi_reference text,
  started_at timestamptz not null default now(),
  expires_at timestamptz not null
);

-- Denormalized flag for fast RLS/UI checks
alter table profiles add column tier text not null default 'free'
  check (tier in ('free', 'power_seller'));

-- Enforce the free-tier cap at insert time
create or replace function check_listing_limit()
returns trigger as $$
begin
  if (select tier from profiles where id = new.seller_id) = 'free'
     and (select count(*) from listings where seller_id = new.seller_id and status = 'active') >= 3
  then
    raise exception 'Free tier limit reached — upgrade to Power Seller';
  end if;
  return new;
end;
$$ language plpgsql;

create trigger enforce_listing_limit
  before insert on listings
  for each row execute function check_listing_limit();
```

---

## 5. Payment architecture — two flows, one processor

**Escrow (unchanged):** Fapshi Direct Pay inside the app → `escrow_transactions` → `pg_cron` polling/auto-release → payout. This stays exactly as documented.

**Power Seller subscription (new — and here's the important part):**

I want to correct something I told you a couple of messages ago. I'd flagged that a listing-quota subscription would likely need Google Play Billing since it unlocks in-app functionality. After digging further, there's a cleaner path that sidesteps the question entirely: **sell the subscription on the web, not inside the Flutter app.**

- User taps "Become a Power Seller" → opens `bookbridge.cm/upgrade` in a browser (not an in-app purchase flow)
- Checkout happens there via Fapshi — the exact same processor and webhook pattern you already use for escrow
- Your Axum webhook handler receives the confirmation, sets `profiles.tier = 'power_seller'` and inserts the `subscriptions` row
- Next time the app syncs, the unlock is already reflected server-side

Because no purchase flow is initiated *from inside the installed app binary*, this generally sits outside Google Play Billing's requirements regardless of region — which matters because the recent Play Store billing changes (external payment links, lower commission) from the Epic v. Google case have so far rolled out mainly for US users, with EU covered separately under the DMA. There's no indication yet that Cameroon-region users are covered, so building something that depends on those freedoms would be building on uncertain ground. Web-only checkout avoids that question altogether and reuses infrastructure you've already built and tested.

*(Standard caveat: I'm not a lawyer — this is a technical/architecture read of publicly available Play policy info, not legal advice. Worth a final sanity check against Play's current developer policy page before you ship it.)*

---

## 6. Rust/Axum service — routes

Extending the route list already defined in your migration plan:

```
/escrow       — existing, Phase 1
/fraud        — existing, Phase 2+
/ai           — existing, Phase 3 (book cover classification)
/webhooks     — existing, handles Fapshi callbacks — extend to branch on
                transaction type (escrow vs subscription) rather than
                adding a separate endpoint
/bundles      — existing, Booklist Bundles feature
/subscriptions — NEW: create/verify/expire Power Seller subscriptions
```

**Framework: Axum.** Not just because it's solid (it is — async-first, built on Tokio, pairs cleanly with `sqlx` for direct Postgres access to your Supabase instance) but because Marketimise already uses Axum + SvelteKit + Postgres with Ken. One Rust web framework across every DevSafe product means shared patterns, shared middleware, and one less thing either of you has to context-switch on.

---

## 7. Hosting: Render free tier (revised — you asked for fully free for now)

This updates my earlier Railway recommendation. Railway no longer has a permanent free tier — it removed it in 2024 and now only offers a one-time trial credit that runs out. That doesn't fit "free for now." Render's free web-service tier does: 750 hours/month of instance time, which is enough to run **one service continuously, all month, for $0**.

The one real trade-off: a Render free instance spins down after 15 minutes with no traffic, so the next request (e.g. a Fapshi webhook firing after a quiet stretch) takes 10–30 seconds to wake up, instead of responding instantly. For a pre-revenue app with modest traffic, that's a real but survivable cost — most payment gateways retry a slow/failed webhook automatically, and you can neutralize it entirely for free:

- Add a `/health` route to the Axum service
- A GitHub Actions scheduled workflow (`cron` in the YAML, runs on GitHub's free minutes) pings it every 10 minutes
- This keeps the instance warm at zero cost — same trick people use to stop Supabase free projects from pausing, just pointed at your own service instead

**Recommendation: deploy the Axum service on Render's free tier for Phase 1 and Phase 2 both**, with the health-check heartbeat above. Revisit only once real transaction volume makes the cold-start risk meaningfully worse, or once escrow + subscription revenue can comfortably justify Render's $25/mo Pro tier for an always-warm instance.

---

## 7a. Is Supabase free tier still right, given escrow already handles real money?

Worth being direct about this rather than glossing over it: Supabase's free plan (500MB database, 1GB file storage, 50,000 MAUs, 500K Edge Function invocations) pauses a project after 7 days with **no database activity** — but your `auto-release-escrows-job` (hourly) and `fapshi-polling-job` (every 5 minutes) both run direct database queries, so as long as those keep firing, the project almost certainly never goes quiet long enough to trigger a pause. That part should already take care of itself.

The gap that's real and worth naming: **the free plan has no automated backups.** For a project storing other people's money mid-escrow, that's the one place "free" carries genuine risk — not inconvenience, actual data-loss-affecting-real-users risk. If this project isn't already on Pro ($25/mo, includes daily backups), the cheapest fully-free mitigation is a scheduled GitHub Actions workflow that runs `pg_dump` against the database on a recurring basis and stores the dump as a private repo artifact. It's not as good as Supabase's managed backups, but it's a real safety net at zero cost, and it's worth having regardless of which tier you're on.

If you already know this project is on Pro, ignore this section — the free-tier plan below is about the *new* pieces (the Axum service), not asking you to downgrade something already carrying live money.

---

## 8. Free-tier stack summary

| Layer | Tech | Cost |
|---|---|---|
| Mobile app | Flutter/Dart | Free — open source SDK |
| Web/landing | SvelteKit + Vite | Free — open source, static hosting |
| Business logic | Rust + Axum | Free — open source framework |
| Hosting for Axum | Render free tier + GitHub Actions heartbeat | $0/month |
| Database/Auth/Storage | Supabase free plan | $0/month (backup gap — see §7a) |
| Payments | Fapshi | Not a hosting cost — per-transaction fee, same as today, applies regardless of tier |
| CI / repo | GitHub | Free tier — 2,000 Actions minutes/month covers the heartbeat + backup workflows easily |

This gets you to a genuinely $0/month infra bill for everything new in v2.0, with the backup gap in §7a as the one thing worth deciding on with clear eyes rather than by default.

---

## 8. Migration phases (reaffirmed from Master Context, subscription work inserted)

| Phase | What | Why this order |
|---|---|---|
| 1 | Replace `process-escrow`, `fapshi-polling` Deno functions with Axum **+ new `/subscriptions` handler** | Stateless, isolated, lowest risk — the subscription flow belongs here since it's equally stateless |
| 2 | Replace SvelteKit Fapshi webhook handler with Axum | Real money moves here — Rust's ownership model prevents null payment references reaching the DB |
| 3 | AI inference layer in Rust (`candle` or `ort`) | Book cover classification for the AI Listing Assistant |
| 4 | Optional: custom Rust auth | Only if specific requirements emerge — Supabase Auth is already good |

**Readiness signal — unchanged, still the gate:** don't start Phase 1 until you can write an Axum handler that validates a Fapshi webhook signature, updates the database, and returns a typed response — from memory, without reaching for docs on basic async/await. That's the actual signal, not a course completion.

---

## 9. Sequencing note

You've currently got the Play Store launch itself, Eventra, the TIP project, and OpenApp all in flight. This entire plan is a **v1.6/v2.0 item** — nothing here should compete with shipping v1.5.0. The free-tier cap increase (1→3 listings) is cheap enough to land in Supabase directly whenever you want; the Rust migration and subscription checkout are the parts that wait for the readiness signal and some breathing room.

---

## 10. Feeding this into Antigravity

When you're ready to start Phase 1, this doc plus your Master Context doc gives Antigravity what it needs: the exact route list, the schema additions in §4, and the constraint that Supabase stays the source of truth while Axum takes over business logic. Worth prompting it to scaffold the `/subscriptions` handler and the webhook branching logic in §5 together, since they share the same Fapshi signature-verification code path as `/escrow`.
