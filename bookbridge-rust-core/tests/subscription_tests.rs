//! Power Seller subscriptions (#39): upgrade codes, checkout, the webhook
//! branch, the free-tier listing cap, and expiry.
//!
//! Pure tests always run. Database tests only run against a local
//! `DATABASE_URL` and skip otherwise; Fapshi is replaced by a local mock.

use axum::{
    body::Body,
    http::{Request, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use bookbridge_rust_core::{
    routes::{
        payments::{parse_external_ref, subscription_external_id, ExternalRef},
        subscriptions::{subscription_routes, validate_upgrade_code},
        webhook::fapshi_webhook_handler,
    },
    user_auth::SupabaseAuth,
    AppState,
};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, PgPool, Row};
use std::collections::HashSet;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

const WEBHOOK_SECRET: &str = "sub_test_wh_secret";

fn state_with(pool: PgPool, fapshi_base_url: String) -> AppState {
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url,
        push: Default::default(),
        rate_limits: Default::default(),
        supabase_auth: SupabaseAuth::new("http://127.0.0.1:1", "test-anon-key"),
    }
}

fn app(state: AppState) -> Router {
    subscription_routes()
        .route("/webhooks/fapshi", post(fapshi_webhook_handler))
        .with_state(state)
}

async fn send(app: &Router, req: Request<Body>) -> (StatusCode, Value) {
    let res = app.clone().oneshot(req).await.unwrap();
    let status = res.status();
    let bytes = axum::body::to_bytes(res.into_body(), usize::MAX)
        .await
        .unwrap();
    let body = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    (status, body)
}

fn post_json(uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method("POST")
        .uri(uri)
        .header("Content-Type", "application/json")
        .body(Body::from(body.to_string()))
        .unwrap()
}

fn get_req(uri: &str) -> Request<Body> {
    Request::builder().uri(uri).body(Body::empty()).unwrap()
}

// ---------------------------------------------------------------- pure tests

#[test]
fn subscription_external_id_round_trips() {
    let user_id = Uuid::new_v4();
    let id = subscription_external_id(user_id, 1_700_000_000_000);
    assert!(id.starts_with("subscription_"));
    assert!(id.len() <= 100);
    assert!(id
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'));
    match parse_external_ref(&id) {
        Some(ExternalRef::Subscription { user_id: parsed }) => assert_eq!(parsed, user_id),
        other => panic!("unexpected parse: {other:?}"),
    }
    assert!(parse_external_ref("subscription_not-a-uuid_1").is_none());
}

#[test]
fn upgrade_codes_are_32_lowercase_hex() {
    let code = Uuid::new_v4().simple().to_string();
    assert!(validate_upgrade_code(&code).is_ok());
    assert!(validate_upgrade_code(&code.to_uppercase()).is_err());
    assert!(validate_upgrade_code(&code[..31]).is_err());
    assert!(validate_upgrade_code(&format!("{}g", &code[..31])).is_err());
    assert!(validate_upgrade_code("").is_err());
    assert!(validate_upgrade_code("' or 1=1 --").is_err());
}

fn unreachable_pool() -> PgPool {
    PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(500))
        .connect_lazy("postgres://u:p@127.0.0.1:1/unreachable")
        .unwrap()
}

#[tokio::test]
async fn upgrade_code_requires_a_token() {
    let app = app(state_with(unreachable_pool(), "http://127.0.0.1:1".into()));
    let (status, _) = send(&app, post_json("/subscriptions/upgrade-code", json!({}))).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn initiate_and_status_validate_before_the_database() {
    let app = app(state_with(unreachable_pool(), "http://127.0.0.1:1".into()));
    let code = Uuid::new_v4().simple().to_string();

    for body in [
        json!({ "code": "nope", "phone": "677123456" }),
        json!({ "code": code, "phone": "12345" }),
        json!({ "code": code, "phone": "677123456", "medium": "bitcoin" }),
    ] {
        let (status, _) = send(&app, post_json("/subscriptions/initiate", body)).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    let (status, _) = send(&app, get_req("/subscriptions/status?code=nope")).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
}

// ------------------------------------------------------------ database tests

async fn local_pool() -> Option<PgPool> {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").ok()?;
    let local = (url.contains("localhost") || url.contains("127.0.0.1"))
        && !url.contains("supabase.com")
        && !url.contains("jacnsvcwmhoicuuzmrmr");
    if !local {
        println!("Skipping subscription DB tests (non-local DATABASE_URL)");
        return None;
    }
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping subscription DB tests (connection failed: {e})");
            None
        }
    }
}

async fn make_user(pool: &PgPool) -> Uuid {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO auth.users (id, email) VALUES ($1, $2)")
        .bind(id)
        .bind(format!("sub-{id}@example.com"))
        .execute(pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO profiles (id, full_name) VALUES ($1, 'Sub Tester')")
        .bind(id)
        .execute(pool)
        .await
        .unwrap();
    id
}

async fn set_webhook_secrets(pool: &PgPool) {
    sqlx::query(
        "INSERT INTO app_secrets (key, value) VALUES \
         ('fapshi_collection_webhook_secret', $1), \
         ('fapshi_collection_api_user', 'sub_user'), \
         ('fapshi_collection_api_key', 'sub_key') \
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value",
    )
    .bind(WEBHOOK_SECRET)
    .execute(pool)
    .await
    .unwrap();
}

async fn tier(pool: &PgPool, user_id: Uuid) -> String {
    sqlx::query_scalar("SELECT tier FROM profiles WHERE id = $1")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .unwrap()
}

async fn insert_listing(pool: &PgPool, seller_id: Uuid, status: &str) -> Result<(), sqlx::Error> {
    sqlx::query(
        "INSERT INTO listings (seller_id, title, author, price_fcfa, condition, status) \
         VALUES ($1, 'Cap Book', 'Author', 1000, 'good', $2)",
    )
    .bind(seller_id)
    .bind(status)
    .execute(pool)
    .await
    .map(|_| ())
}

fn webhook(trans_id: &str, amount: i64, external_id: &str) -> Request<Body> {
    Request::builder()
        .method("POST")
        .uri("/webhooks/fapshi")
        .header("Content-Type", "application/json")
        .header("x-wh-secret", WEBHOOK_SECRET)
        .body(Body::from(
            json!({
                "status": "SUCCESSFUL",
                "transId": trans_id,
                "amount": amount,
                "externalId": external_id,
            })
            .to_string(),
        ))
        .unwrap()
}

fn trans_id() -> String {
    format!("subtx{}", Uuid::new_v4().simple())
}

#[tokio::test]
async fn webhook_grants_tier_idempotently_and_extends_expiry() {
    let Some(pool) = local_pool().await else {
        return;
    };
    set_webhook_secrets(&pool).await;
    let app = app(state_with(pool.clone(), "http://127.0.0.1:1".into()));
    let user = make_user(&pool).await;
    assert_eq!(tier(&pool, user).await, "free");

    let first = trans_id();
    let ext = subscription_external_id(user, 1);
    let (status, _) = send(&app, webhook(&first, 500, &ext)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(tier(&pool, user).await, "power_seller");

    // Fapshi retries the same webhook: no second subscription.
    let (status, _) = send(&app, webhook(&first, 500, &ext)).await;
    assert_eq!(status, StatusCode::OK);
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM subscriptions WHERE user_id = $1")
        .bind(user)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(count, 1);

    // Renewing early stacks on top of the current period.
    let (status, _) = send(
        &app,
        webhook(&trans_id(), 500, &subscription_external_id(user, 2)),
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let days: f64 = sqlx::query_scalar(
        "SELECT extract(epoch FROM max(expires_at) - now())::float8 / 86400 \
         FROM subscriptions WHERE user_id = $1",
    )
    .bind(user)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(
        (59.9..60.1).contains(&days),
        "expected ~60 days, got {days}"
    );
}

#[tokio::test]
async fn underpaid_subscription_is_recorded_not_granted() {
    let Some(pool) = local_pool().await else {
        return;
    };
    set_webhook_secrets(&pool).await;
    let app = app(state_with(pool.clone(), "http://127.0.0.1:1".into()));
    let user = make_user(&pool).await;
    let tx = trans_id();

    let (status, _) = send(&app, webhook(&tx, 100, &subscription_external_id(user, 1))).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(tier(&pool, user).await, "free");
    let unmatched: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM fapshi_audit_logs \
         WHERE endpoint = 'webhook/unmatched-payment' AND request_payload->>'transId' = $1",
    )
    .bind(&tx)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(unmatched, 1);
}

#[tokio::test]
async fn free_sellers_are_capped_at_three_available_listings() {
    let Some(pool) = local_pool().await else {
        return;
    };
    let seller = make_user(&pool).await;

    for _ in 0..3 {
        insert_listing(&pool, seller, "available").await.unwrap();
    }
    let err = insert_listing(&pool, seller, "available")
        .await
        .unwrap_err();
    let db = err.as_database_error().expect("database error");
    assert_eq!(db.code().as_deref(), Some("P0001"));
    assert!(db.message().contains("free_tier_limit"));

    // Non-available rows don't count against or trip the cap.
    insert_listing(&pool, seller, "sold").await.unwrap();

    // Power sellers aren't capped. Give the seller a real active subscription:
    // expire_power_sellers(), run concurrently by another test, downgrades any
    // power seller without one.
    sqlx::query(
        "INSERT INTO subscriptions (user_id, tier, status, fapshi_reference, amount, started_at, expires_at) \
         VALUES ($1, 'power_seller', 'active', $2, 500, now(), now() + interval '30 days')",
    )
    .bind(seller)
    .bind(trans_id())
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("UPDATE profiles SET tier = 'power_seller' WHERE id = $1")
        .bind(seller)
        .execute(&pool)
        .await
        .unwrap();
    insert_listing(&pool, seller, "available").await.unwrap();
    insert_listing(&pool, seller, "available").await.unwrap();

    // Lapsing back to free keeps (grandfathers) the 5 listings but blocks new ones.
    sqlx::query("UPDATE subscriptions SET status = 'expired' WHERE user_id = $1")
        .bind(seller)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("UPDATE profiles SET tier = 'free' WHERE id = $1")
        .bind(seller)
        .execute(&pool)
        .await
        .unwrap();
    let available: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM listings WHERE seller_id = $1 AND status = 'available'",
    )
    .bind(seller)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(available, 5);
    assert!(insert_listing(&pool, seller, "available").await.is_err());
}

#[tokio::test]
async fn expire_power_sellers_downgrades_lapsed_users_only() {
    let Some(pool) = local_pool().await else {
        return;
    };
    let lapsed = make_user(&pool).await;
    let current = make_user(&pool).await;
    for (user, offset) in [(lapsed, "-1 day"), (current, "10 days")] {
        sqlx::query("UPDATE profiles SET tier = 'power_seller' WHERE id = $1")
            .bind(user)
            .execute(&pool)
            .await
            .unwrap();
        sqlx::query(
            "INSERT INTO subscriptions (user_id, tier, status, fapshi_reference, amount, started_at, expires_at) \
             VALUES ($1, 'power_seller', 'active', $2, 500, now() - interval '30 days', now() + $3::interval)",
        )
        .bind(user)
        .bind(trans_id())
        .bind(offset)
        .execute(&pool)
        .await
        .unwrap();
    }

    sqlx::query("SELECT public.expire_power_sellers()")
        .execute(&pool)
        .await
        .unwrap();

    assert_eq!(tier(&pool, lapsed).await, "free");
    assert_eq!(tier(&pool, current).await, "power_seller");
    let lapsed_status: String =
        sqlx::query_scalar("SELECT status FROM subscriptions WHERE user_id = $1")
            .bind(lapsed)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(lapsed_status, "expired");
}

/// Mock Fapshi: direct-pay succeeds unless `fail` is set; status is PENDING.
async fn spawn_mock_fapshi(fail: Arc<AtomicBool>) -> String {
    let app = Router::new()
        .route(
            "/direct-pay",
            post(move || {
                let fail = fail.clone();
                async move {
                    if fail.load(Ordering::SeqCst) {
                        (
                            StatusCode::BAD_REQUEST,
                            Json(json!({ "message": "declined" })),
                        )
                            .into_response()
                    } else {
                        Json(json!({ "transId": "mocktx123" })).into_response()
                    }
                }
            }),
        )
        .route(
            "/payment-status/:id",
            get(|| async { Json(json!({ "status": "PENDING" })) }),
        );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

async fn insert_code(pool: &PgPool, user: Uuid, expires: &str) -> String {
    let code = Uuid::new_v4().simple().to_string();
    sqlx::query(
        "INSERT INTO upgrade_codes (code, user_id, expires_at) VALUES ($1, $2, now() + $3::interval)",
    )
    .bind(&code)
    .bind(user)
    .bind(expires)
    .execute(pool)
    .await
    .unwrap();
    code
}

#[tokio::test]
async fn upgrade_code_checkout_flow() {
    let Some(pool) = local_pool().await else {
        return;
    };
    set_webhook_secrets(&pool).await;
    let fail = Arc::new(AtomicBool::new(true));
    let app = app(state_with(
        pool.clone(),
        spawn_mock_fapshi(fail.clone()).await,
    ));
    let user = make_user(&pool).await;
    let code = insert_code(&pool, user, "15 minutes").await;
    let status_uri = format!("/subscriptions/status?code={code}");
    let initiate = || {
        post_json(
            "/subscriptions/initiate",
            json!({ "code": code, "phone": "677123456" }),
        )
    };

    let (status, body) = send(&app, get_req(&status_uri)).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["status"], "UNUSED");
    assert_eq!(body["price_xaf"], 500);

    // Fapshi rejects: the code is released so the user can retry.
    let (status, _) = send(&app, initiate()).await;
    assert_eq!(status, StatusCode::BAD_GATEWAY);
    let (_, body) = send(&app, get_req(&status_uri)).await;
    assert_eq!(body["status"], "UNUSED");

    fail.store(false, Ordering::SeqCst);
    let (status, body) = send(&app, initiate()).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["status"], "PENDING");
    let row = sqlx::query(
        "SELECT used_at IS NOT NULL AS used, trans_id FROM upgrade_codes WHERE code = $1",
    )
    .bind(&code)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert!(row.get::<bool, _>("used"));
    assert_eq!(
        row.get::<Option<String>, _>("trans_id").as_deref(),
        Some("mocktx123")
    );

    // Single use.
    let (status, _) = send(&app, initiate()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    let (_, body) = send(&app, get_req(&status_uri)).await;
    assert_eq!(body["status"], "PENDING");

    // Expired and unknown codes.
    let expired = insert_code(&pool, user, "-1 minute").await;
    let (_, body) = send(
        &app,
        get_req(&format!("/subscriptions/status?code={expired}")),
    )
    .await;
    assert_eq!(body["status"], "EXPIRED");
    let (status, _) = send(
        &app,
        post_json(
            "/subscriptions/initiate",
            json!({ "code": expired, "phone": "677123456" }),
        ),
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT);
    let unknown = Uuid::new_v4().simple().to_string();
    let (status, _) = send(
        &app,
        get_req(&format!("/subscriptions/status?code={unknown}")),
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}
