//! Double-sell guard (#52).
//!
//! Supabase Auth and Fapshi are replaced by local mock servers. These tests
//! need a database and run only when `DATABASE_URL` points at a local/test
//! Postgres loaded with `tests/fixtures/production_schema.sql` plus the
//! migrations newer than it; otherwise they print a skip notice and pass.

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header::AUTHORIZATION, HeaderMap, Method, Request, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use bookbridge_rust_core::{
    routes::{
        escrow::poll_pending_handler, payments::payment_routes, webhook::fapshi_webhook_handler,
    },
    user_auth::SupabaseAuth,
    AppState,
};
use serde_json::{json, Value};
use sqlx::{PgPool, Row};
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use tower::ServiceExt;
use uuid::Uuid;

const ANON_KEY: &str = "test-anon-key";
const WEBHOOK_SECRET: &str = "wh_test_key_xyz";
const ALREADY_SOLD_REASON: &str = "listing already sold to another buyer";
const PRICE: i64 = 500;

// ---------------------------------------------------------------- mocks

async fn serve(app: Router) -> String {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

/// Mock Supabase Auth: each token maps to one user id.
async fn spawn_mock_auth(tokens: HashMap<String, Uuid>) -> String {
    let tokens = Arc::new(tokens);
    let app = Router::new().route(
        "/auth/v1/user",
        get(move |headers: HeaderMap| {
            let tokens = tokens.clone();
            async move {
                let key_ok = headers.get("apikey").is_some_and(|v| v == ANON_KEY);
                let user = headers
                    .get(AUTHORIZATION)
                    .and_then(|v| v.to_str().ok())
                    .and_then(|v| v.strip_prefix("Bearer "))
                    .and_then(|t| tokens.get(t));
                match (key_ok, user) {
                    (true, Some(id)) => Json(json!({ "id": id })).into_response(),
                    _ => StatusCode::UNAUTHORIZED.into_response(),
                }
            }
        }),
    );
    serve(app).await
}

/// Mock Fapshi collection API. `direct-pay` fails while `fail_direct_pay`
/// is set; `payment-status` answers from `statuses`.
#[derive(Default)]
struct MockFapshi {
    fail_direct_pay: bool,
    direct_pays: usize,
    statuses: HashMap<String, String>,
}

type Fapshi = Arc<Mutex<MockFapshi>>;

async fn spawn_mock_fapshi(fapshi: Fapshi) -> String {
    async fn direct_pay(State(f): State<Fapshi>) -> impl IntoResponse {
        let mut f = f.lock().unwrap();
        if f.fail_direct_pay {
            return (
                StatusCode::BAD_REQUEST,
                Json(json!({ "message": "Invalid phone" })),
            )
                .into_response();
        }
        f.direct_pays += 1;
        Json(json!({ "transId": format!("dp{}", Uuid::new_v4().simple()) })).into_response()
    }
    async fn status(State(f): State<Fapshi>, Path(id): Path<String>) -> impl IntoResponse {
        match f.lock().unwrap().statuses.get(&id) {
            Some(s) => Json(json!({ "status": s })).into_response(),
            None => (
                StatusCode::NOT_FOUND,
                Json(json!({ "message": "not found" })),
            )
                .into_response(),
        }
    }
    let app = Router::new()
        .route("/direct-pay", post(direct_pay))
        .route("/payment-status/:id", get(status))
        .with_state(fapshi);
    serve(app).await
}

// ---------------------------------------------------------------- world

async fn test_db() -> Option<PgPool> {
    let _ = dotenvy::dotenv();
    let url = match std::env::var("DATABASE_URL") {
        Ok(url)
            if (url.contains("localhost") || url.contains("127.0.0.1"))
                && !url.contains("supabase") =>
        {
            url
        }
        _ => {
            println!("Skipping double-sell DB integration test (needs a local DATABASE_URL)");
            return None;
        }
    };
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping double-sell DB integration test (cannot connect: {e})");
            None
        }
    }
}

const BUYER_A: &str = "buyer-a";
const BUYER_B: &str = "buyer-b";

struct World {
    state: AppState,
    fapshi: Fapshi,
    pool: PgPool,
    listing: Uuid,
    seller: Uuid,
    buyer_a: Uuid,
    buyer_b: Uuid,
}

/// One available 500 XAF listing and two would-be buyers.
async fn world() -> Option<World> {
    let pool = test_db().await?;
    let (seller, buyer_a, buyer_b) = (Uuid::new_v4(), Uuid::new_v4(), Uuid::new_v4());
    sqlx::query("INSERT INTO auth.users (id) VALUES ($1), ($2), ($3)")
        .bind(seller)
        .bind(buyer_a)
        .bind(buyer_b)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query(
        "INSERT INTO profiles (id, full_name) VALUES ($1, 'Seller'), ($2, 'Buyer A'), ($3, 'Buyer B')",
    )
    .bind(seller)
    .bind(buyer_a)
    .bind(buyer_b)
    .execute(&pool)
    .await
    .unwrap();
    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id, status) \
         VALUES ('Contested Book', 'Author', $1, 'good', $2, 'available') RETURNING id",
    )
    .bind(PRICE as i32)
    .bind(seller)
    .fetch_one(&pool)
    .await
    .unwrap();
    for (key, value) in [
        ("fapshi_collection_api_user", "wh_test_payout_user"),
        ("fapshi_collection_api_key", "wh_test_payout_key"),
        ("fapshi_collection_webhook_secret", WEBHOOK_SECRET),
    ] {
        sqlx::query(
            "INSERT INTO app_secrets (key, value) VALUES ($1, $2) \
             ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value",
        )
        .bind(key)
        .bind(value)
        .execute(&pool)
        .await
        .unwrap();
    }
    let auth_url = spawn_mock_auth(HashMap::from([
        (BUYER_A.to_string(), buyer_a),
        (BUYER_B.to_string(), buyer_b),
    ]))
    .await;
    let fapshi: Fapshi = Arc::default();
    let fapshi_url = spawn_mock_fapshi(fapshi.clone()).await;
    let state = AppState {
        pool: pool.clone(),
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: fapshi_url,
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    };
    Some(World {
        state,
        fapshi,
        pool,
        listing,
        seller,
        buyer_a,
        buyer_b,
    })
}

impl World {
    async fn initiate(&self, token: &str) -> (StatusCode, Value) {
        let body = json!({ "kind": "purchase", "listing_id": self.listing, "phone": "677123456" });
        let req = Request::builder()
            .method(Method::POST)
            .uri("/payments/initiate")
            .header(AUTHORIZATION, format!("Bearer {token}"))
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        let res = payment_routes()
            .with_state(self.state.clone())
            .oneshot(req)
            .await
            .unwrap();
        read(res).await
    }

    async fn webhook(&self, status: &str, reference: &str, buyer: Uuid) -> StatusCode {
        let body = json!({
            "status": status,
            "transId": reference,
            "amount": PRICE,
            "externalId": format!("purchase_{}_{}_1", self.listing, buyer),
        });
        let req = Request::builder()
            .method(Method::POST)
            .uri("/webhooks/fapshi")
            .header("content-type", "application/json")
            .header("x-wh-secret", WEBHOOK_SECRET)
            .body(Body::from(body.to_string()))
            .unwrap();
        let app = Router::new()
            .route("/webhooks/fapshi", post(fapshi_webhook_handler))
            .with_state(self.state.clone());
        app.oneshot(req).await.unwrap().status()
    }

    async fn poll(&self) -> Value {
        let req = Request::builder()
            .method(Method::POST)
            .uri("/escrow/poll-pending")
            .body(Body::empty())
            .unwrap();
        let app = Router::new()
            .route("/escrow/poll-pending", post(poll_pending_handler))
            .with_state(self.state.clone());
        let (status, body) = read(app.oneshot(req).await.unwrap()).await;
        assert_eq!(status, StatusCode::OK, "{body}");
        body
    }

    /// A `pending_payment` purchase as `/payments/initiate` records it.
    async fn pending_tx(&self, buyer: Uuid, minutes_old: i32) -> (Uuid, String) {
        let reference = format!("ref{}", Uuid::new_v4().simple());
        let id: Uuid = sqlx::query_scalar(
            "INSERT INTO transactions (listing_id, buyer_id, seller_id, amount, commission_amount, \
             payment_reference, status, payout_status, created_at) \
             VALUES ($1, $2, $3, $4, 25, $5, 'pending_payment', 'pending', \
                     now() - make_interval(mins => $6)) RETURNING id",
        )
        .bind(self.listing)
        .bind(buyer)
        .bind(self.seller)
        .bind(PRICE as i32)
        .bind(&reference)
        .bind(minutes_old)
        .fetch_one(&self.pool)
        .await
        .unwrap();
        (id, reference)
    }

    async fn reservation_holder(&self) -> Option<Uuid> {
        sqlx::query_scalar("SELECT buyer_id FROM listing_reservations WHERE listing_id = $1")
            .bind(self.listing)
            .fetch_optional(&self.pool)
            .await
            .unwrap()
    }

    async fn listing_status(&self) -> String {
        sqlx::query_scalar("SELECT status FROM listings WHERE id = $1")
            .bind(self.listing)
            .fetch_one(&self.pool)
            .await
            .unwrap()
    }

    async fn tx_status(&self, id: Uuid) -> String {
        sqlx::query_scalar("SELECT status FROM transactions WHERE id = $1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .unwrap()
    }

    async fn unmatched(&self, reference: &str) -> Vec<Value> {
        sqlx::query(
            "SELECT request_payload FROM fapshi_audit_logs \
             WHERE endpoint = 'webhook/unmatched-payment' AND request_payload->>'transId' = $1",
        )
        .bind(reference)
        .fetch_all(&self.pool)
        .await
        .unwrap()
        .into_iter()
        .map(|r| r.get("request_payload"))
        .collect()
    }

    async fn held_escrows(&self) -> i64 {
        sqlx::query_scalar(
            "SELECT count(*) FROM escrow_transactions e JOIN transactions t ON t.id = e.transaction_id \
             WHERE t.listing_id = $1 AND e.status = 'held'",
        )
        .bind(self.listing)
        .fetch_one(&self.pool)
        .await
        .unwrap()
    }
}

async fn read(res: axum::response::Response) -> (StatusCode, Value) {
    let status = res.status();
    let bytes = axum::body::to_bytes(res.into_body(), usize::MAX)
        .await
        .unwrap();
    (
        status,
        serde_json::from_slice(&bytes).unwrap_or(Value::Null),
    )
}

// ---------------------------------------------------------------- initiate

#[tokio::test]
async fn second_buyer_is_turned_away_while_first_is_paying() {
    let Some(w) = world().await else { return };

    let (status, body) = w.initiate(BUYER_A).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(w.reservation_holder().await, Some(w.buyer_a));

    let (status, body) = w.initiate(BUYER_B).await;
    assert_eq!(status, StatusCode::CONFLICT, "{body}");
    assert_eq!(w.reservation_holder().await, Some(w.buyer_a));
    assert_eq!(w.fapshi.lock().unwrap().direct_pays, 1);
}

#[tokio::test]
async fn same_buyer_can_retry_while_holding_the_reservation() {
    let Some(w) = world().await else { return };

    assert_eq!(w.initiate(BUYER_A).await.0, StatusCode::OK);
    assert_eq!(w.initiate(BUYER_A).await.0, StatusCode::OK);
    assert_eq!(w.reservation_holder().await, Some(w.buyer_a));
    assert_eq!(w.fapshi.lock().unwrap().direct_pays, 2);
}

#[tokio::test]
async fn expired_reservation_can_be_taken_over() {
    let Some(w) = world().await else { return };

    assert_eq!(w.initiate(BUYER_A).await.0, StatusCode::OK);
    sqlx::query(
        "UPDATE listing_reservations SET reserved_until = now() - interval '1 minute' \
         WHERE listing_id = $1",
    )
    .bind(w.listing)
    .execute(&w.pool)
    .await
    .unwrap();

    let (status, body) = w.initiate(BUYER_B).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(w.reservation_holder().await, Some(w.buyer_b));
}

#[tokio::test]
async fn failed_payment_prompt_releases_the_reservation() {
    let Some(w) = world().await else { return };
    w.fapshi.lock().unwrap().fail_direct_pay = true;

    let (status, body) = w.initiate(BUYER_A).await;
    assert_eq!(status, StatusCode::BAD_GATEWAY, "{body}");
    assert_eq!(w.reservation_holder().await, None);

    w.fapshi.lock().unwrap().fail_direct_pay = false;
    assert_eq!(w.initiate(BUYER_B).await.0, StatusCode::OK);
    assert_eq!(w.reservation_holder().await, Some(w.buyer_b));
}

// ---------------------------------------------------------------- webhook

#[tokio::test]
async fn failed_webhook_releases_the_reservation() {
    let Some(w) = world().await else { return };

    let (status, body) = w.initiate(BUYER_A).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let reference: String = sqlx::query_scalar(
        "SELECT payment_reference FROM transactions WHERE listing_id = $1 AND buyer_id = $2",
    )
    .bind(w.listing)
    .bind(w.buyer_a)
    .fetch_one(&w.pool)
    .await
    .unwrap();

    assert_eq!(
        w.webhook("FAILED", &reference, w.buyer_a).await,
        StatusCode::OK
    );
    assert_eq!(w.reservation_holder().await, None);
    assert_eq!(w.initiate(BUYER_B).await.0, StatusCode::OK);
}

#[tokio::test]
async fn second_successful_payment_is_failed_and_queued_for_refund() {
    let Some(w) = world().await else { return };
    let (tx_a, ref_a) = w.pending_tx(w.buyer_a, 0).await;
    let (tx_b, ref_b) = w.pending_tx(w.buyer_b, 0).await;

    assert_eq!(
        w.webhook("SUCCESSFUL", &ref_a, w.buyer_a).await,
        StatusCode::OK
    );
    assert_eq!(w.tx_status(tx_a).await, "held");
    assert_eq!(w.listing_status().await, "sold");

    assert_eq!(
        w.webhook("SUCCESSFUL", &ref_b, w.buyer_b).await,
        StatusCode::OK
    );
    assert_eq!(w.tx_status(tx_b).await, "failed");
    assert_eq!(w.tx_status(tx_a).await, "held");
    assert_eq!(w.held_escrows().await, 1);

    let unmatched = w.unmatched(&ref_b).await;
    assert_eq!(unmatched.len(), 1);
    assert_eq!(unmatched[0]["reason"], ALREADY_SOLD_REASON);
    assert!(w.unmatched(&ref_a).await.is_empty());

    // Fapshi retries the webhook: no second refund entry.
    assert_eq!(
        w.webhook("SUCCESSFUL", &ref_b, w.buyer_b).await,
        StatusCode::OK
    );
    assert_eq!(w.unmatched(&ref_b).await.len(), 1);
}

// ---------------------------------------------------------------- poller

#[tokio::test]
async fn poller_fails_a_successful_payment_for_a_sold_listing() {
    let Some(w) = world().await else { return };
    let (tx_a, ref_a) = w.pending_tx(w.buyer_a, 20).await;
    let (tx_b, ref_b) = w.pending_tx(w.buyer_b, 20).await;
    {
        let mut f = w.fapshi.lock().unwrap();
        f.statuses.insert(ref_a.clone(), "SUCCESSFUL".to_string());
        f.statuses.insert(ref_b.clone(), "SUCCESSFUL".to_string());
    }

    let body = w.poll().await;
    let status_of = |reference: &str| {
        body["results"]
            .as_array()
            .unwrap()
            .iter()
            .find(|r| r["reference"] == reference)
            .map(|r| r["status"].as_str().unwrap().to_string())
    };
    let mut outcomes = [status_of(&ref_a).unwrap(), status_of(&ref_b).unwrap()];
    outcomes.sort();
    assert_eq!(outcomes, ["already_sold", "held"]);

    assert_eq!(w.listing_status().await, "sold");
    assert_eq!(w.held_escrows().await, 1);
    let (loser_tx, loser_ref) = if status_of(&ref_a).unwrap() == "held" {
        (tx_b, ref_b)
    } else {
        (tx_a, ref_a)
    };
    assert_eq!(w.tx_status(loser_tx).await, "failed");
    let unmatched = w.unmatched(&loser_ref).await;
    assert_eq!(unmatched.len(), 1);
    assert_eq!(unmatched[0]["reason"], ALREADY_SOLD_REASON);
}
