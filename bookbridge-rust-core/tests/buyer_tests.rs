//! Buyer endpoints: authentication and validation paths.
//!
//! Supabase Auth is replaced by a local mock server. The database pool points
//! at a closed port, so a 500 means the request got past auth and validation
//! and reached the database, and nothing here touches a real database.

use axum::{
    body::Body,
    http::{header::AUTHORIZATION, HeaderMap, Request, StatusCode},
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use bookbridge_rust_core::{
    error::AppError,
    routes::buyer::{buyer_routes, validate_dispute_reason, MAX_DISPUTE_REASON_CHARS},
    user_auth::{bearer_token, SupabaseAuth},
    AppState,
};
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use std::collections::HashSet;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

const ANON_KEY: &str = "test-anon-key";
const GOOD_TOKEN: &str = "good-token";

async fn spawn_mock_supabase_auth(user_id: Uuid) -> String {
    let app = Router::new().route(
        "/auth/v1/user",
        get(move |headers: HeaderMap| async move {
            let key_ok = headers.get("apikey").is_some_and(|v| v == ANON_KEY);
            let auth = headers.get(AUTHORIZATION).and_then(|v| v.to_str().ok());
            match (key_ok, auth) {
                (true, Some("Bearer good-token")) => Json(json!({ "id": user_id })).into_response(),
                (true, Some("Bearer malformed-response")) => {
                    Json(json!({ "no": "id" })).into_response()
                }
                (true, Some("Bearer auth-down")) => StatusCode::SERVICE_UNAVAILABLE.into_response(),
                _ => StatusCode::UNAUTHORIZED.into_response(),
            }
        }),
    );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

async fn test_state() -> AppState {
    let auth_url = spawn_mock_supabase_auth(Uuid::new_v4()).await;
    let pool = PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(500))
        .connect_lazy("postgres://user:pass@127.0.0.1:1/unreachable")
        .unwrap();
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        rate_limits: Default::default(),
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    }
}

async fn post(state: &AppState, path: &str, auth: Option<&str>, body: &str) -> StatusCode {
    let mut req = Request::builder()
        .method("POST")
        .uri(path)
        .header("content-type", "application/json");
    if let Some(value) = auth {
        req = req.header(AUTHORIZATION, value);
    }
    let app = buyer_routes().with_state(state.clone());
    app.oneshot(req.body(Body::from(body.to_string())).unwrap())
        .await
        .unwrap()
        .status()
}

fn confirm_body() -> String {
    json!({ "transaction_id": Uuid::new_v4() }).to_string()
}

fn dispute_body(reason: &str) -> String {
    json!({ "transaction_id": Uuid::new_v4(), "dispute_reason": reason }).to_string()
}

const ENDPOINTS: [&str; 2] = ["/escrow/confirm-receipt", "/escrow/dispute"];

#[tokio::test]
async fn rejects_missing_or_invalid_credentials() {
    let state = test_state().await;
    let body = dispute_body("Book never arrived");
    for path in ENDPOINTS {
        assert_eq!(
            post(&state, path, None, &body).await,
            StatusCode::UNAUTHORIZED,
            "{path} no header"
        );
        assert_eq!(
            post(&state, path, Some("Bearer wrong-token"), &body).await,
            StatusCode::UNAUTHORIZED,
            "{path} bad token"
        );
        assert_eq!(
            post(&state, path, Some("Basic good-token"), &body).await,
            StatusCode::UNAUTHORIZED,
            "{path} wrong scheme"
        );
        assert_eq!(
            post(&state, path, Some("Bearer "), &body).await,
            StatusCode::UNAUTHORIZED,
            "{path} empty token"
        );
    }
}

#[tokio::test]
async fn authenticates_before_reading_the_body() {
    let state = test_state().await;
    for path in ENDPOINTS {
        assert_eq!(
            post(&state, path, None, "not json").await,
            StatusCode::UNAUTHORIZED,
            "{path}"
        );
    }
}

#[tokio::test]
async fn auth_service_failures_are_bad_gateway_not_success() {
    let state = test_state().await;
    let body = confirm_body();
    let path = "/escrow/confirm-receipt";
    assert_eq!(
        post(&state, path, Some("Bearer auth-down"), &body).await,
        StatusCode::BAD_GATEWAY
    );
    assert_eq!(
        post(&state, path, Some("Bearer malformed-response"), &body).await,
        StatusCode::BAD_GATEWAY
    );
}

#[tokio::test]
async fn unreachable_auth_service_is_bad_gateway() {
    let mut state = test_state().await;
    state.supabase_auth = SupabaseAuth::new("http://127.0.0.1:1", ANON_KEY);
    let status = post(
        &state,
        "/escrow/confirm-receipt",
        Some("Bearer good-token"),
        &confirm_body(),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_GATEWAY);
}

#[tokio::test]
async fn valid_token_reaches_the_database() {
    let state = test_state().await;
    let auth = format!("Bearer {GOOD_TOKEN}");
    assert_eq!(
        post(
            &state,
            "/escrow/confirm-receipt",
            Some(&auth),
            &confirm_body()
        )
        .await,
        StatusCode::INTERNAL_SERVER_ERROR
    );
    assert_eq!(
        post(
            &state,
            "/escrow/dispute",
            Some(&auth),
            &dispute_body("Wrong edition")
        )
        .await,
        StatusCode::INTERNAL_SERVER_ERROR
    );
}

#[tokio::test]
async fn rejects_malformed_bodies_from_authenticated_users() {
    let state = test_state().await;
    let auth = format!("Bearer {GOOD_TOKEN}");
    for (path, body) in [
        ("/escrow/confirm-receipt", json!({}).to_string()),
        (
            "/escrow/confirm-receipt",
            json!({ "transaction_id": "not-a-uuid" }).to_string(),
        ),
        (
            "/escrow/dispute",
            json!({ "transaction_id": Uuid::new_v4() }).to_string(),
        ),
    ] {
        let status = post(&state, path, Some(&auth), &body).await;
        assert!(
            status.is_client_error() && status != StatusCode::UNAUTHORIZED,
            "{path} {body} -> {status}"
        );
    }
}

#[tokio::test]
async fn dispute_validates_reason_before_touching_the_database() {
    let state = test_state().await;
    let auth = format!("Bearer {GOOD_TOKEN}");
    let too_long = "x".repeat(MAX_DISPUTE_REASON_CHARS + 1);
    for reason in ["", "   ", too_long.as_str()] {
        let status = post(
            &state,
            "/escrow/dispute",
            Some(&auth),
            &dispute_body(reason),
        )
        .await;
        assert_eq!(
            status,
            StatusCode::BAD_REQUEST,
            "reason len {}",
            reason.len()
        );
    }
}

#[tokio::test]
async fn dispute_is_refused_while_a_payout_is_in_progress() {
    let state = test_state().await;
    let tx_id = Uuid::new_v4();
    state.in_progress_payouts.lock().unwrap().insert(tx_id);

    let body = json!({ "transaction_id": tx_id, "dispute_reason": "Damaged" }).to_string();
    let status = post(
        &state,
        "/escrow/dispute",
        Some(&format!("Bearer {GOOD_TOKEN}")),
        &body,
    )
    .await;

    assert_eq!(status, StatusCode::CONFLICT);
    assert!(
        state.in_progress_payouts.lock().unwrap().contains(&tx_id),
        "must not release another caller's lock"
    );
}

#[tokio::test]
async fn dispute_releases_its_lock_when_done() {
    let state = test_state().await;
    let tx_id = Uuid::new_v4();
    let body = json!({ "transaction_id": tx_id, "dispute_reason": "Damaged" }).to_string();
    post(
        &state,
        "/escrow/dispute",
        Some(&format!("Bearer {GOOD_TOKEN}")),
        &body,
    )
    .await;
    assert!(state.in_progress_payouts.lock().unwrap().is_empty());
}

#[tokio::test]
async fn supabase_auth_returns_the_token_owner() {
    let user_id = Uuid::new_v4();
    let auth = SupabaseAuth::new(spawn_mock_supabase_auth(user_id).await, ANON_KEY);
    assert_eq!(auth.user_id(GOOD_TOKEN).await.unwrap(), user_id);
}

#[tokio::test]
async fn supabase_auth_sends_the_anon_key() {
    let auth = SupabaseAuth::new(
        spawn_mock_supabase_auth(Uuid::new_v4()).await,
        "wrong-anon-key",
    );
    assert!(matches!(
        auth.user_id(GOOD_TOKEN).await,
        Err(AppError::Unauthorized(_))
    ));
}

#[test]
fn bearer_token_parsing() {
    let headers = |v: &str| {
        let mut h = HeaderMap::new();
        h.insert(AUTHORIZATION, v.parse().unwrap());
        h
    };
    assert_eq!(bearer_token(&headers("Bearer abc")).unwrap(), "abc");
    assert_eq!(bearer_token(&headers("bearer abc")).unwrap(), "abc");
    assert!(bearer_token(&headers("Bearer")).is_err());
    assert!(bearer_token(&headers("Token abc")).is_err());
    assert!(bearer_token(&HeaderMap::new()).is_err());
}

#[test]
fn dispute_reason_is_trimmed_and_bounded() {
    assert_eq!(
        validate_dispute_reason("  Missing pages \n").unwrap(),
        "Missing pages"
    );
    assert!(validate_dispute_reason(&"é".repeat(MAX_DISPUTE_REASON_CHARS)).is_ok());
    assert!(validate_dispute_reason(&"é".repeat(MAX_DISPUTE_REASON_CHARS + 1)).is_err());
}
