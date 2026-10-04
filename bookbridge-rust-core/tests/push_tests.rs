//! Push notification dispatch (#37).
//!
//! Google OAuth and FCM are replaced by local mock servers. The RSA key for
//! the fake service account is generated with `openssl` at test time so no
//! private key is committed. Database tests run only when `DATABASE_URL`
//! points at a local Postgres loaded with the schema fixture, the newer
//! migrations and `tests/fixtures/supabase_extensions_stub.sql`; otherwise
//! they print a skip notice and pass.

use axum::{
    body::Body,
    extract::State,
    http::{HeaderMap, Request, StatusCode},
    response::IntoResponse,
    routing::post,
    Form, Json, Router,
};
use bookbridge_rust_core::{
    push::{FcmClient, PushService},
    routes::push::{dispatch_push_handler, MAX_PUSH_ATTEMPTS},
    user_auth::SupabaseAuth,
    AppState,
};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, PgPool, Row};
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

const ACCESS_TOKEN: &str = "mock-access-token";

// ---------------------------------------------------------------- helpers

/// The dispatcher drains every pending row, so DB tests must not overlap.
static DB_LOCK: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

async fn serve(app: Router) -> String {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

#[derive(Default)]
struct MockGoogle {
    oauth_calls: usize,
    /// Every FCM request body received, in order.
    sent: Vec<Value>,
}

type Google = Arc<Mutex<MockGoogle>>;

/// Mock OAuth token endpoint plus FCM. FCM answers by token prefix:
/// `ok-` succeeds, `dead-` is UNREGISTERED, anything else is a 500.
async fn spawn_mock_google(google: Google) -> String {
    async fn token(
        State(g): State<Google>,
        Form(form): Form<HashMap<String, String>>,
    ) -> impl IntoResponse {
        let ok = form.get("grant_type").map(String::as_str)
            == Some("urn:ietf:params:oauth:grant-type:jwt-bearer")
            && form
                .get("assertion")
                .is_some_and(|a| a.split('.').count() == 3);
        if !ok {
            return StatusCode::BAD_REQUEST.into_response();
        }
        g.lock().unwrap().oauth_calls += 1;
        Json(json!({ "access_token": ACCESS_TOKEN, "expires_in": 3600 })).into_response()
    }
    async fn send(
        State(g): State<Google>,
        headers: HeaderMap,
        Json(body): Json<Value>,
    ) -> impl IntoResponse {
        let bearer = format!("Bearer {ACCESS_TOKEN}");
        if headers
            .get("authorization")
            .is_none_or(|v| v != bearer.as_str())
        {
            return StatusCode::UNAUTHORIZED.into_response();
        }
        let token = body["message"]["token"]
            .as_str()
            .unwrap_or_default()
            .to_string();
        g.lock().unwrap().sent.push(body);
        if token.starts_with("ok-") {
            Json(json!({ "name": "projects/test-project/messages/1" })).into_response()
        } else if token.starts_with("dead-") {
            (
                StatusCode::NOT_FOUND,
                Json(json!({ "error": {
                    "code": 404, "status": "NOT_FOUND",
                    "message": "Requested entity was not found.",
                    "details": [{ "errorCode": "UNREGISTERED" }]
                }})),
            )
                .into_response()
        } else {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": { "code": 500, "message": "backend error" } })),
            )
                .into_response()
        }
    }
    let app = Router::new()
        .route("/token", post(token))
        .route("/v1/projects/test-project/messages:send", post(send))
        .with_state(google);
    serve(app).await
}

fn test_private_key() -> Option<String> {
    let out = std::process::Command::new("openssl")
        .args([
            "genpkey",
            "-algorithm",
            "RSA",
            "-pkeyopt",
            "rsa_keygen_bits:2048",
        ])
        .output()
        .ok()?;
    out.status
        .success()
        .then(|| String::from_utf8(out.stdout).unwrap())
}

fn fcm_client(base_url: &str, private_key: &str) -> FcmClient {
    let sa = json!({
        "type": "service_account",
        "project_id": "test-project",
        "client_email": "push@test-project.iam.gserviceaccount.com",
        "private_key": private_key,
        "token_uri": format!("{base_url}/token"),
    });
    FcmClient::from_service_account_json(&sa.to_string())
        .unwrap()
        .with_fcm_base_url(base_url)
}

fn state_with(pool: PgPool, push: PushService) -> AppState {
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        supabase_auth: SupabaseAuth::new("http://127.0.0.1:1", "unused"),
        rate_limits: Default::default(),
        push,
    }
}

async fn dispatch(state: &AppState) -> Value {
    let res = Router::new()
        .route("/push/dispatch", post(dispatch_push_handler))
        .with_state(state.clone())
        .oneshot(Request::post("/push/dispatch").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::OK);
    let bytes = axum::body::to_bytes(res.into_body(), usize::MAX)
        .await
        .unwrap();
    serde_json::from_slice(&bytes).unwrap()
}

// ---------------------------------------------- service config (no database)

#[test]
fn invalid_service_account_json_is_rejected() {
    assert!(FcmClient::from_service_account_json("not json").is_err());
    let bad_key = json!({
        "project_id": "p", "client_email": "e", "private_key": "nope", "token_uri": "http://x"
    });
    assert!(FcmClient::from_service_account_json(&bad_key.to_string()).is_err());
}

#[tokio::test]
async fn concurrent_dispatch_is_a_no_op() {
    // Returns before touching the database, so an unreachable pool is fine.
    let pool = PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(200))
        .connect_lazy("postgres://postgres@127.0.0.1:1/unreachable")
        .unwrap();
    let state = state_with(pool, PushService::default());
    let _held = state.push.dispatch_lock.lock().await;
    let resp = dispatch(&state).await;
    assert_eq!(resp["ran"], false);
    assert_eq!(resp["sent"], 0);
}

// ------------------------------------------------- database integration

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
            println!("Skipping push DB integration test (needs a local DATABASE_URL)");
            return None;
        }
    };
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping push DB integration test (cannot connect: {e})");
            None
        }
    }
}

/// A seller with a listing and a buyer, each with the given FCM token.
struct Sale {
    seller: Uuid,
    buyer: Uuid,
    listing: Uuid,
}

async fn seed_sale(pool: &PgPool, seller_token: Option<&str>, buyer_token: Option<&str>) -> Sale {
    let (seller, buyer) = (Uuid::new_v4(), Uuid::new_v4());
    sqlx::query("INSERT INTO auth.users (id) VALUES ($1), ($2)")
        .bind(seller)
        .bind(buyer)
        .execute(pool)
        .await
        .unwrap();
    // The profiles -> profiles_private sync copies fcm_token across.
    sqlx::query(
        "INSERT INTO profiles (id, full_name, fcm_token) VALUES ($1, 'Seller', $2), ($3, 'Buyer', $4)",
    )
    .bind(seller)
    .bind(seller_token)
    .bind(buyer)
    .bind(buyer_token)
    .execute(pool)
    .await
    .unwrap();
    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id, status) \
         VALUES ('Physics F5', 'Author', 1000, 'good', $1, 'available') RETURNING id",
    )
    .bind(seller)
    .fetch_one(pool)
    .await
    .unwrap();
    Sale {
        seller,
        buyer,
        listing,
    }
}

async fn insert_notification(pool: &PgPool, user: Uuid, title: &str) -> Uuid {
    sqlx::query_scalar(
        "INSERT INTO notifications (user_id, type, title, body, data) \
         VALUES ($1, 'payment_confirmed', $2, 'body', $3) RETURNING id",
    )
    .bind(user)
    .bind(title)
    .bind(json!({ "listing_id": "L1", "count": 3, "skip": null }))
    .fetch_one(pool)
    .await
    .unwrap()
}

#[derive(Debug)]
struct PushState {
    sent_at: bool,
    attempts: i32,
    error: Option<String>,
}

async fn push_state(pool: &PgPool, id: Uuid) -> PushState {
    let row = sqlx::query(
        "SELECT push_sent_at IS NOT NULL AS sent, push_attempts, push_error \
         FROM notifications WHERE id = $1",
    )
    .bind(id)
    .fetch_one(pool)
    .await
    .unwrap();
    PushState {
        sent_at: row.get("sent"),
        attempts: row.get("push_attempts"),
        error: row.get("push_error"),
    }
}

async fn tokens(pool: &PgPool, user: Uuid) -> (Option<String>, Option<String>) {
    let public: Option<String> = sqlx::query_scalar("SELECT fcm_token FROM profiles WHERE id = $1")
        .bind(user)
        .fetch_one(pool)
        .await
        .unwrap();
    let private: Option<String> = sqlx::query_scalar::<_, Option<String>>(
        "SELECT fcm_token FROM profiles_private WHERE id = $1",
    )
    .bind(user)
    .fetch_optional(pool)
    .await
    .unwrap()
    .flatten();
    (public, private)
}

async fn net_calls(pool: &PgPool) -> i64 {
    sqlx::query_scalar("SELECT count(*) FROM net._calls")
        .fetch_one(pool)
        .await
        .unwrap()
}

struct World {
    pool: PgPool,
    google: Google,
    state: AppState,
}

async fn world() -> Option<World> {
    let pool = test_db().await?;
    let Some(key) = test_private_key() else {
        println!("Skipping push DB integration test (openssl not available)");
        return None;
    };
    let google: Google = Arc::default();
    let base = spawn_mock_google(google.clone()).await;
    let state = state_with(
        pool.clone(),
        PushService::new(Some(fcm_client(&base, &key))),
    );
    Some(World {
        pool,
        google,
        state,
    })
}

fn sent_to(google: &Google, token: &str) -> Vec<Value> {
    google
        .lock()
        .unwrap()
        .sent
        .iter()
        .filter(|b| b["message"]["token"] == token)
        .cloned()
        .collect()
}

#[tokio::test]
async fn delivers_pending_rows_and_records_each_outcome() {
    let _db = DB_LOCK.lock().await;
    let Some(w) = world().await else { return };
    let ok = format!("ok-{}", Uuid::new_v4());
    let dead = format!("dead-{}", Uuid::new_v4());
    let flaky = format!("fail-{}", Uuid::new_v4());
    let a = seed_sale(&w.pool, Some(&ok), None).await;
    let b = seed_sale(&w.pool, Some(&dead), Some(&flaky)).await;

    let delivered = insert_notification(&w.pool, a.seller, "delivered").await;
    let delivered_too = insert_notification(&w.pool, a.seller, "delivered too").await;
    let tokenless = insert_notification(&w.pool, a.buyer, "no token").await;
    let invalid = insert_notification(&w.pool, b.seller, "invalid").await;
    let failing = insert_notification(&w.pool, b.buyer, "failing").await;

    let resp = dispatch(&w.state).await;
    assert_eq!(resp["ran"], true);
    assert_eq!(resp["configured"], true);

    let s = push_state(&w.pool, delivered).await;
    assert!(s.sent_at && s.error.is_none() && s.attempts == 0, "{s:?}");
    assert!(push_state(&w.pool, delivered_too).await.sent_at);

    let s = push_state(&w.pool, tokenless).await;
    assert!(s.sent_at, "{s:?}");
    assert_eq!(s.error.as_deref(), Some("no_token"));

    let s = push_state(&w.pool, invalid).await;
    assert!(s.sent_at, "{s:?}");
    assert!(s.error.unwrap().starts_with("invalid_token"));
    assert_eq!(tokens(&w.pool, b.seller).await, (None, None));

    // A transient failure stays pending for the next run, and is tried only
    // once per run.
    let s = push_state(&w.pool, failing).await;
    assert!(!s.sent_at && s.attempts == 1, "{s:?}");
    assert!(s.error.unwrap().contains("500"));
    assert_eq!(sent_to(&w.google, &flaky).len(), 1);
    assert_eq!(
        tokens(&w.pool, b.buyer).await,
        (Some(flaky.clone()), Some(flaky.clone()))
    );

    // Message shape: stringified data, type added, nulls dropped, channel set.
    let msg = &sent_to(&w.google, &ok)[0]["message"];
    assert_eq!(msg["notification"]["body"], "body");
    assert_eq!(msg["data"]["type"], "payment_confirmed");
    assert_eq!(msg["data"]["listing_id"], "L1");
    assert_eq!(msg["data"]["count"], "3");
    assert!(msg["data"].get("skip").is_none());
    assert_eq!(
        msg["android"]["notification"]["channel_id"],
        "high_importance_channel"
    );

    // The access token is cached across sends and runs.
    dispatch(&w.state).await;
    assert_eq!(w.google.lock().unwrap().oauth_calls, 1);
    assert_eq!(
        sent_to(&w.google, &ok).len(),
        2,
        "delivered rows are not resent"
    );
    assert_eq!(push_state(&w.pool, failing).await.attempts, 2);
}

#[tokio::test]
async fn final_failed_attempt_closes_the_row() {
    let _db = DB_LOCK.lock().await;
    let Some(w) = world().await else { return };
    let flaky = format!("fail-{}", Uuid::new_v4());
    let sale = seed_sale(&w.pool, Some(&flaky), None).await;
    let id = insert_notification(&w.pool, sale.seller, "last try").await;
    sqlx::query("UPDATE notifications SET push_attempts = $2 WHERE id = $1")
        .bind(id)
        .bind(MAX_PUSH_ATTEMPTS - 1)
        .execute(&w.pool)
        .await
        .unwrap();

    dispatch(&w.state).await;
    let s = push_state(&w.pool, id).await;
    assert!(s.sent_at, "{s:?}");
    assert_eq!(s.attempts, MAX_PUSH_ATTEMPTS);
    assert!(s.error.unwrap().contains("500"));

    dispatch(&w.state).await;
    assert_eq!(
        sent_to(&w.google, &flaky).len(),
        1,
        "closed rows are not retried"
    );
}

#[tokio::test]
async fn stale_rows_expire_instead_of_sending() {
    let _db = DB_LOCK.lock().await;
    let Some(w) = world().await else { return };
    let ok = format!("ok-{}", Uuid::new_v4());
    let sale = seed_sale(&w.pool, Some(&ok), None).await;
    let id = insert_notification(&w.pool, sale.seller, "old news").await;
    sqlx::query("UPDATE notifications SET created_at = now() - interval '25 hours' WHERE id = $1")
        .bind(id)
        .execute(&w.pool)
        .await
        .unwrap();

    let resp = dispatch(&w.state).await;
    assert!(resp["expired"].as_u64().unwrap() >= 1);
    let s = push_state(&w.pool, id).await;
    assert!(s.sent_at);
    assert_eq!(s.error.as_deref(), Some("expired"));
    assert!(sent_to(&w.google, &ok).is_empty());
}

#[tokio::test]
async fn unconfigured_fcm_leaves_rows_pending() {
    let _db = DB_LOCK.lock().await;
    let Some(pool) = test_db().await else { return };
    let ok = format!("ok-{}", Uuid::new_v4());
    let sale = seed_sale(&pool, Some(&ok), None).await;
    let id = insert_notification(&pool, sale.seller, "waiting").await;

    let state = state_with(pool.clone(), PushService::default());
    let resp = dispatch(&state).await;
    assert_eq!(resp["ran"], true);
    assert_eq!(resp["configured"], false);
    let s = push_state(&pool, id).await;
    assert!(!s.sent_at && s.attempts == 0, "{s:?}");

    // Leave nothing pending for the other tests' assertions.
    sqlx::query("UPDATE notifications SET push_sent_at = now() WHERE id = $1")
        .bind(id)
        .execute(&pool)
        .await
        .unwrap();
}

// ------------------------------------------------------- database triggers

async fn notifications_for(pool: &PgPool, user: Uuid) -> Vec<(String, String, Value)> {
    sqlx::query(
        "SELECT type, title, data FROM notifications WHERE user_id = $1 ORDER BY created_at, title",
    )
    .bind(user)
    .fetch_all(pool)
    .await
    .unwrap()
    .into_iter()
    .map(|r| (r.get("type"), r.get("title"), r.get("data")))
    .collect()
}

#[tokio::test]
async fn payment_status_changes_notify_both_parties_and_wake_the_dispatcher() {
    let _db = DB_LOCK.lock().await;
    let Some(pool) = test_db().await else { return };
    let sale = seed_sale(&pool, None, None).await;
    let calls_before = net_calls(&pool).await;

    let tx: Uuid = sqlx::query_scalar(
        "INSERT INTO transactions (listing_id, buyer_id, seller_id, amount, commission_amount, \
         payment_reference, status, payout_status) \
         VALUES ($1, $2, $3, 1000, 50, $4, 'pending_payment', 'pending') RETURNING id",
    )
    .bind(sale.listing)
    .bind(sale.buyer)
    .bind(sale.seller)
    .bind(format!("ref-{}", Uuid::new_v4()))
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(notifications_for(&pool, sale.buyer).await.is_empty());
    assert_eq!(
        net_calls(&pool).await,
        calls_before,
        "no rows, no dispatch call"
    );

    let set_status = |status: &'static str| {
        let pool = pool.clone();
        async move {
            sqlx::query("UPDATE transactions SET status = $2 WHERE id = $1")
                .bind(tx)
                .bind(status)
                .execute(&pool)
                .await
                .unwrap();
        }
    };

    set_status("held").await;
    set_status("held").await; // unchanged status: no duplicate
    let buyer = notifications_for(&pool, sale.buyer).await;
    let seller = notifications_for(&pool, sale.seller).await;
    assert_eq!(buyer.len(), 1);
    assert_eq!(seller.len(), 1);
    assert_eq!(buyer[0].1, "Payment received 🔒");
    assert_eq!(seller[0].1, "You made a sale! 💰");
    assert_eq!(buyer[0].2["status"], "held");
    assert_eq!(buyer[0].2["transaction_id"], tx.to_string());
    assert_eq!(buyer[0].2["listing_id"], sale.listing.to_string());
    // One INSERT statement of two rows is one dispatcher call.
    assert_eq!(net_calls(&pool).await, calls_before + 1);

    let call = sqlx::query("SELECT url, headers FROM net._calls ORDER BY id DESC LIMIT 1")
        .fetch_one(&pool)
        .await
        .unwrap();
    let url: String = call.get("url");
    let headers: Value = call.get("headers");
    assert!(url.ends_with("/internal/push/dispatch"));
    assert_eq!(headers["X-Internal-Secret"], "local-test-secret");

    set_status("successful").await;
    assert_eq!(notifications_for(&pool, sale.buyer).await.len(), 2);
    assert_eq!(notifications_for(&pool, sale.seller).await.len(), 2);

    // A failed payment only concerns the buyer.
    let sale2 = seed_sale(&pool, None, None).await;
    sqlx::query(
        "INSERT INTO transactions (listing_id, buyer_id, seller_id, amount, commission_amount, \
         payment_reference, status, payout_status) \
         VALUES ($1, $2, $3, 1000, 50, $4, 'failed', 'pending')",
    )
    .bind(sale2.listing)
    .bind(sale2.buyer)
    .bind(sale2.seller)
    .bind(format!("ref-{}", Uuid::new_v4()))
    .execute(&pool)
    .await
    .unwrap();
    assert_eq!(notifications_for(&pool, sale2.buyer).await.len(), 1);
    assert!(notifications_for(&pool, sale2.seller).await.is_empty());

    close_all(&pool).await;
}

#[tokio::test]
async fn messages_notify_the_receiver_as_inquiry_or_reply() {
    let _db = DB_LOCK.lock().await;
    let Some(pool) = test_db().await else { return };
    let sale = seed_sale(&pool, None, None).await;
    let send_message = |from: Uuid, to: Uuid, content: String| {
        let pool = pool.clone();
        async move {
            sqlx::query(
                "INSERT INTO messages (listing_id, sender_id, receiver_id, content) VALUES ($1, $2, $3, $4)",
            )
            .bind(sale.listing)
            .bind(from)
            .bind(to)
            .bind(content)
            .execute(&pool)
            .await
            .unwrap();
        }
    };

    send_message(sale.buyer, sale.seller, "Is it still available?".into()).await;
    send_message(sale.seller, sale.buyer, "x".repeat(200)).await;
    send_message(sale.buyer, sale.buyer, "note to self".into()).await;

    let seller = notifications_for(&pool, sale.seller).await;
    assert_eq!(seller.len(), 1);
    assert_eq!(seller[0].0, "new_inquiry");
    assert_eq!(seller[0].1, "New inquiry about \"Physics F5\"");
    assert_eq!(seller[0].2["listing_id"], sale.listing.to_string());
    assert_eq!(seller[0].2["sender_id"], sale.buyer.to_string());

    let buyer = notifications_for(&pool, sale.buyer).await;
    assert_eq!(buyer.len(), 1, "self-messages do not notify");
    assert_eq!(buyer[0].0, "new_message");
    let body: String = sqlx::query_scalar("SELECT body FROM notifications WHERE user_id = $1")
        .bind(sale.buyer)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(
        body.chars().count(),
        121,
        "preview is cut to 120 chars plus an ellipsis"
    );

    close_all(&pool).await;
}

/// Marks every pending row as handled so trigger tests do not leave work
/// for the dispatcher tests.
async fn close_all(pool: &PgPool) {
    sqlx::query("UPDATE notifications SET push_sent_at = now() WHERE push_sent_at IS NULL")
        .execute(pool)
        .await
        .unwrap();
}
