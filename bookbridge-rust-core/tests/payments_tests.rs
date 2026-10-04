//! Payment endpoints: authentication, validation, and the externalId format.
//!
//! Supabase Auth is replaced by a local mock server. The database pool points
//! at a closed port, so a 500 means the request got past auth and validation
//! and reached the database, and nothing here touches a real database or Fapshi.

use axum::{
    body::Body,
    http::{header::AUTHORIZATION, HeaderMap, Request, StatusCode},
    response::IntoResponse,
    routing::get,
    Json, Router,
};
use bookbridge_rust_core::{
    routes::payments::{
        boost_external_id, buyer_fee_for, covers_expected, donation_external_id,
        parse_external_ref, payment_routes, purchase_external_id, seller_payout,
        validate_donation_amount, validate_medium, validate_phone, validate_trans_id, ExternalRef,
        BOOST_DAYS, MAX_DONATION_XAF, MIN_AMOUNT_XAF,
    },
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
const GOOD_TOKEN: &str = "good-token";

async fn spawn_mock_supabase_auth(user_id: Uuid) -> String {
    let good = format!("Bearer {GOOD_TOKEN}");
    let app = Router::new().route(
        "/auth/v1/user",
        get(move |headers: HeaderMap| {
            let good = good.clone();
            async move {
                let key_ok = headers.get("apikey").is_some_and(|v| v == ANON_KEY);
                let auth = headers.get(AUTHORIZATION).and_then(|v| v.to_str().ok());
                if key_ok && auth == Some(good.as_str()) {
                    Json(json!({ "id": user_id })).into_response()
                } else {
                    StatusCode::UNAUTHORIZED.into_response()
                }
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
        // Validation tests send many requests from one user; keep limits out of the way.
        push: Default::default(),
        rate_limits: bookbridge_rust_core::rate_limit::RateLimits::new(
            bookbridge_rust_core::rate_limit::RateLimitSettings {
                payment_initiations_per_user: 1_000,
                per_user: 1_000,
                ..Default::default()
            },
        ),
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    }
}

fn good_auth() -> String {
    format!("Bearer {GOOD_TOKEN}")
}

async fn send(
    state: &AppState,
    method: &str,
    path: &str,
    auth: Option<&str>,
    body: Option<Value>,
) -> StatusCode {
    let mut req = Request::builder().method(method).uri(path);
    if let Some(value) = auth {
        req = req.header(AUTHORIZATION, value);
    }
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
        .status()
}

async fn initiate(state: &AppState, body: Value) -> StatusCode {
    send(
        state,
        "POST",
        "/payments/initiate",
        Some(&good_auth()),
        Some(body),
    )
    .await
}

fn purchase_body() -> Value {
    json!({ "kind": "purchase", "listing_id": Uuid::new_v4(), "phone": "677123456" })
}

#[tokio::test]
async fn endpoints_require_a_valid_token() {
    let state = test_state().await;
    let initiate_path = "/payments/initiate";
    let status_path = "/payments/status/abc123";
    for auth in [None, Some("Bearer wrong-token"), Some("Basic good-token")] {
        assert_eq!(
            send(&state, "POST", initiate_path, auth, Some(purchase_body())).await,
            StatusCode::UNAUTHORIZED,
            "initiate {auth:?}"
        );
        assert_eq!(
            send(&state, "GET", status_path, auth, None).await,
            StatusCode::UNAUTHORIZED,
            "status {auth:?}"
        );
    }
}

#[tokio::test]
async fn initiate_rejects_invalid_input_before_touching_the_database() {
    let state = test_state().await;
    let listing_id = Uuid::new_v4();

    let bad_phone = json!({ "kind": "purchase", "listing_id": listing_id, "phone": "12345" });
    assert_eq!(initiate(&state, bad_phone).await, StatusCode::BAD_REQUEST);

    let bad_medium = json!({
        "kind": "boost", "listing_id": listing_id, "phone": "677123456", "medium": "paypal"
    });
    assert_eq!(initiate(&state, bad_medium).await, StatusCode::BAD_REQUEST);

    for amount in [0, MIN_AMOUNT_XAF - 1, MAX_DONATION_XAF + 1, -500] {
        let body = json!({ "kind": "donation", "amount": amount, "phone": "677123456" });
        assert_eq!(
            initiate(&state, body).await,
            StatusCode::BAD_REQUEST,
            "donation {amount}"
        );
    }
}

#[tokio::test]
async fn initiate_rejects_malformed_bodies() {
    let state = test_state().await;
    let bodies = [
        json!({ "kind": "refund", "listing_id": Uuid::new_v4(), "phone": "677123456" }),
        json!({ "kind": "purchase", "phone": "677123456" }),
        json!({ "kind": "purchase", "listing_id": "not-a-uuid", "phone": "677123456" }),
        json!({ "kind": "donation", "amount": "500", "phone": "677123456" }),
        json!({ "listing_id": Uuid::new_v4(), "phone": "677123456" }),
        // The client must not be able to set the price of a purchase.
        json!({ "kind": "purchase", "listing_id": Uuid::new_v4() }),
    ];
    for body in bodies {
        let status = initiate(&state, body.clone()).await;
        assert!(status.is_client_error(), "{body} gave {status}");
    }
}

#[tokio::test]
async fn valid_requests_reach_the_database() {
    let state = test_state().await;
    let bodies = [
        purchase_body(),
        json!({
            "kind": "boost", "listing_id": Uuid::new_v4(),
            "phone": "+237 690 000 000", "medium": "Orange Money"
        }),
        json!({ "kind": "donation", "amount": 1000, "phone": "650000000", "medium": null }),
    ];
    for body in bodies {
        assert_eq!(
            initiate(&state, body.clone()).await,
            StatusCode::INTERNAL_SERVER_ERROR,
            "{body}"
        );
    }
}

#[tokio::test]
async fn status_validates_the_transaction_id() {
    let state = test_state().await;
    let auth = good_auth();
    for path in [
        "/payments/status/abc%24def",
        "/payments/status/a%2F..%2Fb",
        "/payments/status/%20",
    ] {
        assert_eq!(
            send(&state, "GET", path, Some(&auth), None).await,
            StatusCode::BAD_REQUEST,
            "{path}"
        );
    }
    let long = format!("/payments/status/{}", "a".repeat(101));
    assert_eq!(
        send(&state, "GET", &long, Some(&auth), None).await,
        StatusCode::BAD_REQUEST
    );
    assert_eq!(
        send(
            &state,
            "GET",
            "/payments/status/KGEartB8BK",
            Some(&auth),
            None
        )
        .await,
        StatusCode::INTERNAL_SERVER_ERROR
    );
}

fn is_valid_fapshi_external_id(id: &str) -> bool {
    (1..=100).contains(&id.len())
        && id
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

#[test]
fn external_ids_satisfy_fapshi_and_round_trip() {
    let listing_id = Uuid::new_v4();
    let user_id = Uuid::new_v4();
    let millis = 1_790_000_000_000;

    let purchase = purchase_external_id(listing_id, user_id, millis);
    let boost = boost_external_id(listing_id, millis);
    let donation = donation_external_id(user_id, millis);
    for id in [&purchase, &boost, &donation] {
        assert!(is_valid_fapshi_external_id(id), "{id}");
    }

    assert_eq!(
        parse_external_ref(&purchase),
        Some(ExternalRef::Purchase {
            listing_id,
            buyer_id: user_id
        })
    );
    assert_eq!(
        parse_external_ref(&boost),
        Some(ExternalRef::Boost { listing_id })
    );
    assert!(boost.contains(&format!("_{BOOST_DAYS}_")));
    assert_eq!(
        parse_external_ref(&donation),
        Some(ExternalRef::Donation {
            user_id: Some(user_id)
        })
    );
}

#[test]
fn parse_external_ref_handles_legacy_and_bad_ids() {
    let listing_id = Uuid::new_v4();
    let buyer_id = Uuid::new_v4();
    assert_eq!(
        parse_external_ref(&format!("purchase:{listing_id}:{buyer_id}:123")),
        Some(ExternalRef::Purchase {
            listing_id,
            buyer_id
        })
    );
    assert_eq!(
        parse_external_ref("donation_anonymous_123"),
        Some(ExternalRef::Donation { user_id: None })
    );
    for bad in [
        "",
        "purchase",
        &format!("purchase_{listing_id}"),
        "purchase_x_y_1",
        "boost_nope_7_1",
        "donation_nope_1",
        &format!("refund_{listing_id}_{buyer_id}"),
    ] {
        assert_eq!(parse_external_ref(bad), None, "{bad}");
    }
}

#[test]
fn phone_and_medium_validation() {
    assert_eq!(validate_phone("677123456").unwrap(), "677123456");
    assert_eq!(validate_phone("+237 677 12 34 56").unwrap(), "677123456");
    assert_eq!(validate_phone("237677123456").unwrap(), "677123456");
    for bad in ["", "77123456", "577123456", "6771234567", "phone"] {
        assert!(validate_phone(bad).is_err(), "{bad}");
    }

    assert_eq!(validate_medium(None).unwrap(), None);
    assert_eq!(validate_medium(Some("  ")).unwrap(), None);
    assert_eq!(
        validate_medium(Some("Mobile Money")).unwrap().as_deref(),
        Some("mobile money")
    );
    assert_eq!(
        validate_medium(Some("orange money")).unwrap().as_deref(),
        Some("orange money")
    );
    assert!(validate_medium(Some("momo")).is_err());
}

#[test]
fn amount_rules() {
    assert!(validate_donation_amount(MIN_AMOUNT_XAF).is_ok());
    assert!(validate_donation_amount(MAX_DONATION_XAF).is_ok());
    assert!(validate_donation_amount(MIN_AMOUNT_XAF - 1).is_err());
    assert!(validate_donation_amount(MAX_DONATION_XAF + 1).is_err());

    assert!(covers_expected(5000.0, 5000.0));
    assert!(covers_expected(5001.0, 5000.0));
    assert!(!covers_expected(100.0, 5000.0));
    assert!(!covers_expected(4999.0, 5000.0));

    // The buyer pays 6% on top of the price, rounded up to a whole franc.
    assert_eq!(buyer_fee_for(5000), 300);
    assert_eq!(buyer_fee_for(100), 6);
    assert_eq!(buyer_fee_for(101), 7);
    assert_eq!(buyer_fee_for(0), 0);
    assert_eq!(buyer_fee_for(-50), 0);

    // New sales carry no commission: the seller gets the full price.
    assert_eq!(seller_payout(5000.0, 0.0), Some(5000.0));
    // Legacy sales keep their stored 5% commission.
    assert_eq!(seller_payout(5000.0, 250.0), Some(4750.0));
    // Fapshi rejects payouts below 100 XAF, so small sales pay out the minimum.
    assert_eq!(seller_payout(100.0, 5.0), Some(100.0));
    assert_eq!(seller_payout(103.0, 6.0), Some(100.0));
    assert_eq!(seller_payout(110.0, 6.0), Some(104.0));
    assert_eq!(seller_payout(99.0, 0.0), None);

    assert!(validate_trans_id("KGEartB8BK").is_ok());
    assert!(validate_trans_id("a-b_c").is_ok());
    assert!(validate_trans_id("").is_err());
    assert!(validate_trans_id("a/b").is_err());
}
