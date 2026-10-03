//! Rate limiting over HTTP: per-IP limits on public routes, per-user limits
//! on signed-in routes, and the extra limit on starting a payment.
//!
//! Supabase Auth is replaced by a local mock server and the database pool
//! points at a closed port, so nothing here touches a real database or Fapshi.

use axum::{
    body::{to_bytes, Body},
    http::{header::AUTHORIZATION, header::RETRY_AFTER, HeaderMap, Request, StatusCode},
    middleware,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};
use bookbridge_rust_core::{
    rate_limit::{limit_by_ip, RateLimitSettings, RateLimits},
    routes::payments::payment_routes,
    user_auth::SupabaseAuth,
    AppState,
};
use serde_json::{json, Value};
use sqlx::postgres::PgPoolOptions;
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

const ANON_KEY: &str = "test-anon-key";
const TOKEN: &str = "good-token";

async fn spawn_mock_supabase_auth() -> String {
    let user_id = Uuid::new_v4();
    let app = Router::new().route(
        "/auth/v1/user",
        get(move |headers: HeaderMap| async move {
            let expected = format!("Bearer {TOKEN}");
            let auth = headers.get(AUTHORIZATION).and_then(|v| v.to_str().ok());
            if auth == Some(expected.as_str()) {
                Json(json!({ "id": user_id })).into_response()
            } else {
                StatusCode::UNAUTHORIZED.into_response()
            }
        }),
    );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

async fn state_with(settings: RateLimitSettings) -> AppState {
    let pool = PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(200))
        .connect_lazy("postgres://postgres@127.0.0.1:1/unreachable")
        .unwrap();
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        supabase_auth: SupabaseAuth::new(spawn_mock_supabase_auth().await, ANON_KEY),
        rate_limits: RateLimits::new(settings),
    }
}

fn settings(per_ip: u32, per_user: u32, payment_initiations_per_user: u32) -> RateLimitSettings {
    RateLimitSettings {
        window: Duration::from_secs(60),
        per_ip,
        per_user,
        payment_initiations_per_user,
    }
}

fn ip_limited_app(state: AppState) -> Router {
    Router::new()
        .route("/ping", get(|| async { "pong" }))
        .layer(middleware::from_fn_with_state(state.clone(), limit_by_ip))
        .with_state(state)
}

async fn ping(app: &Router, ip: &str) -> Response {
    let req = Request::builder()
        .uri("/ping")
        .header("cf-connecting-ip", ip)
        .body(Body::empty())
        .unwrap();
    app.clone().oneshot(req).await.unwrap()
}

async fn json_body(response: Response) -> Value {
    let bytes = to_bytes(response.into_body(), usize::MAX).await.unwrap();
    serde_json::from_slice(&bytes).unwrap()
}

async fn assert_too_many_requests(response: Response) {
    assert_eq!(response.status(), StatusCode::TOO_MANY_REQUESTS);
    let retry_after: u64 = response
        .headers()
        .get(RETRY_AFTER)
        .expect("Retry-After header")
        .to_str()
        .unwrap()
        .parse()
        .unwrap();
    assert!((1..=60).contains(&retry_after));

    let body = json_body(response).await;
    let message = body["error"].as_str().unwrap();
    assert!(message.starts_with("Too many requests"), "{message}");
    assert!(message.contains(&retry_after.to_string()), "{message}");
}

#[tokio::test]
async fn an_ip_over_its_limit_gets_429_with_retry_after() {
    let app = ip_limited_app(state_with(settings(2, 100, 100)).await);

    assert_eq!(ping(&app, "1.1.1.1").await.status(), StatusCode::OK);
    assert_eq!(ping(&app, "1.1.1.1").await.status(), StatusCode::OK);
    assert_too_many_requests(ping(&app, "1.1.1.1").await).await;
}

#[tokio::test]
async fn one_ip_hitting_its_limit_does_not_block_another() {
    let app = ip_limited_app(state_with(settings(1, 100, 100)).await);

    assert_eq!(ping(&app, "1.1.1.1").await.status(), StatusCode::OK);
    assert_eq!(
        ping(&app, "1.1.1.1").await.status(),
        StatusCode::TOO_MANY_REQUESTS
    );
    assert_eq!(ping(&app, "2.2.2.2").await.status(), StatusCode::OK);
}

async fn payment_request(
    state: &AppState,
    method: &str,
    path: &str,
    body: Option<Value>,
) -> Response {
    let mut req = Request::builder()
        .method(method)
        .uri(path)
        .header(AUTHORIZATION, format!("Bearer {TOKEN}"));
    let body = match body {
        Some(json) => {
            req = req.header("content-type", "application/json");
            Body::from(json.to_string())
        }
        None => Body::empty(),
    };
    payment_routes()
        .with_state(state.clone())
        .oneshot(req.body(body).unwrap())
        .await
        .unwrap()
}

#[tokio::test]
async fn a_signed_in_user_over_their_limit_gets_429() {
    let state = state_with(settings(100, 2, 100)).await;
    let path = "/payments/status/abc123";

    for _ in 0..2 {
        let response = payment_request(&state, "GET", path, None).await;
        assert_ne!(response.status(), StatusCode::TOO_MANY_REQUESTS);
    }
    assert_too_many_requests(payment_request(&state, "GET", path, None).await).await;
}

#[tokio::test]
async fn starting_payments_has_its_own_lower_limit() {
    let state = state_with(settings(100, 100, 1)).await;
    // Invalid on purpose: the limit is checked before the body is validated,
    // so these never reach the database or Fapshi.
    let body = json!({ "kind": "purchase", "listing_id": Uuid::new_v4(), "phone": "bad" });

    let first = payment_request(&state, "POST", "/payments/initiate", Some(body.clone())).await;
    assert_eq!(first.status(), StatusCode::BAD_REQUEST);
    assert_too_many_requests(
        payment_request(&state, "POST", "/payments/initiate", Some(body)).await,
    )
    .await;

    // Other signed-in routes are still allowed.
    let status = payment_request(&state, "GET", "/payments/status/abc123", None).await;
    assert_ne!(status.status(), StatusCode::TOO_MANY_REQUESTS);
}
