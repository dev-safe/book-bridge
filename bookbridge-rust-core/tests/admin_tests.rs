//! Admin endpoints (#51).
//!
//! Supabase Auth and Fapshi are replaced by local mock servers. Tests that
//! need a database run only when `DATABASE_URL` points at a local/test
//! Postgres loaded with `tests/fixtures/production_schema.sql` plus the
//! migrations newer than it; otherwise they print a skip notice and pass.

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header::AUTHORIZATION, HeaderMap, Method, Request, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use bookbridge_rust_core::{
    error::AppError,
    fapshi::FapshiSearchItem,
    routes::admin::{
        admin_routes, check_payout_minimum, decide_refund_payout, mask_phone, refund_external_id,
        refund_phone, validate_note, RefundPayout, MAX_NOTE_CHARS,
    },
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

const ANON_KEY: &str = "test-anon-key";

// ---------------------------------------------------------------- helpers

fn bad_request(result: Result<impl std::fmt::Debug, AppError>) -> bool {
    matches!(result, Err(AppError::BadRequest(_)))
}

fn item(trans_id: &str, status: &str) -> FapshiSearchItem {
    FapshiSearchItem {
        trans_id: trans_id.to_string(),
        status: status.to_string(),
        external_id: Some("x".to_string()),
    }
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

async fn serve(app: Router) -> String {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

/// Mock Fapshi: payouts are recorded and become SUCCESSFUL search results;
/// search results and collection statuses can be preset per test.
#[derive(Default)]
struct MockFapshi {
    payouts: Vec<Value>,
    search: HashMap<String, Vec<Value>>,
    collections: HashMap<String, Value>,
}

type Fapshi = Arc<Mutex<MockFapshi>>;

async fn spawn_mock_fapshi(fapshi: Fapshi) -> String {
    async fn payout(State(f): State<Fapshi>, Json(body): Json<Value>) -> Json<Value> {
        let mut f = f.lock().unwrap();
        let trans_id = format!("payout{}", f.payouts.len() + 1);
        let external_id = body["externalId"].as_str().unwrap_or_default().to_string();
        f.search
            .entry(external_id.clone())
            .or_default()
            .push(json!({
                "transId": trans_id, "status": "SUCCESSFUL", "externalId": external_id
            }));
        f.payouts.push(body);
        Json(json!({ "transId": trans_id, "message": "Accepted" }))
    }
    async fn search(
        State(f): State<Fapshi>,
        Query(q): Query<HashMap<String, String>>,
    ) -> Json<Value> {
        let f = f.lock().unwrap();
        let ext = q.get("externalId").cloned().unwrap_or_default();
        Json(Value::Array(
            f.search.get(&ext).cloned().unwrap_or_default(),
        ))
    }
    async fn status(State(f): State<Fapshi>, Path(id): Path<String>) -> impl IntoResponse {
        match f.lock().unwrap().collections.get(&id) {
            Some(v) => Json(v.clone()).into_response(),
            None => (
                StatusCode::NOT_FOUND,
                Json(json!({ "message": "not found" })),
            )
                .into_response(),
        }
    }
    let app = Router::new()
        .route("/payout", post(payout))
        .route("/search", get(search))
        .route("/payment-status/:id", get(status))
        .with_state(fapshi);
    serve(app).await
}

async fn send(
    state: &AppState,
    method: Method,
    path: &str,
    token: Option<&str>,
    body: Option<Value>,
) -> (StatusCode, Value) {
    let mut req = Request::builder().method(method).uri(path);
    if let Some(token) = token {
        req = req.header(AUTHORIZATION, format!("Bearer {token}"));
    }
    let body = match body {
        Some(b) => {
            req = req.header("content-type", "application/json");
            Body::from(b.to_string())
        }
        None => Body::empty(),
    };
    let res = admin_routes()
        .with_state(state.clone())
        .oneshot(req.body(body).unwrap())
        .await
        .unwrap();
    let status = res.status();
    let bytes = axum::body::to_bytes(res.into_body(), usize::MAX)
        .await
        .unwrap();
    (
        status,
        serde_json::from_slice(&bytes).unwrap_or(Value::Null),
    )
}

// ------------------------------------------------------------ unit tests

#[test]
fn note_is_required_trimmed_and_bounded() {
    assert!(bad_request(validate_note("")));
    assert!(bad_request(validate_note("   \n")));
    assert!(bad_request(validate_note(&"a".repeat(MAX_NOTE_CHARS + 1))));
    assert_eq!(
        validate_note("  buyer sent photos ").unwrap(),
        "buyer sent photos"
    );
    assert!(validate_note(&"é".repeat(MAX_NOTE_CHARS)).is_ok());
}

#[test]
fn refund_phone_prefers_override_then_recorded() {
    let o = || Some("677000111".to_string());
    let r = || Some("655222333".to_string());
    assert_eq!(refund_phone(o(), r()).unwrap(), "677000111");
    assert_eq!(refund_phone(None, r()).unwrap(), "655222333");
    assert!(bad_request(refund_phone(None, Some("  ".to_string()))));
    assert!(bad_request(refund_phone(None, None)));
}

#[test]
fn payout_minimum_is_100() {
    assert!(bad_request(check_payout_minimum(99)));
    assert!(check_payout_minimum(100).is_ok());
}

#[test]
fn refund_external_id_meets_fapshi_rules() {
    assert_eq!(
        refund_external_id("escrow_refund", "Ab-12_c").unwrap(),
        "escrow_refund_Ab-12_c"
    );
    assert!(bad_request(refund_external_id(
        "escrow_refund",
        "has space"
    )));
    assert!(bad_request(refund_external_id("escrow_refund", "a/b")));
    assert!(bad_request(refund_external_id(
        "escrow_refund",
        &"a".repeat(90)
    )));
}

#[test]
fn phone_mask_hides_the_middle() {
    assert_eq!(mask_phone("677123456"), "677•••456");
    assert_eq!(mask_phone("+237 677 123 456"), "237•••456");
    assert_eq!(mask_phone("12345"), "•••");
}

#[test]
fn refund_payout_decision() {
    assert_eq!(decide_refund_payout(&[]), RefundPayout::Pay);
    assert_eq!(
        decide_refund_payout(&[item("a", "FAILED"), item("b", "expired")]),
        RefundPayout::Pay
    );
    assert_eq!(
        decide_refund_payout(&[item("a", "FAILED"), item("b", "SUCCESSFUL")]),
        RefundPayout::AlreadyPaid("b".to_string())
    );
    // A success wins over a later attempt still in flight.
    assert_eq!(
        decide_refund_payout(&[item("a", "PENDING"), item("b", "successful")]),
        RefundPayout::AlreadyPaid("b".to_string())
    );
    for status in ["PENDING", "CREATED", "SOMETHING_NEW"] {
        assert_eq!(
            decide_refund_payout(&[item("a", "FAILED"), item("b", status)]),
            RefundPayout::InFlight {
                trans_id: "b".to_string(),
                status: status.to_string()
            }
        );
    }
}

// ------------------------------------- auth gate (no database required)

const ROUTES: [(&str, &str); 7] = [
    ("GET", "/admin/me"),
    ("GET", "/admin/disputes"),
    (
        "POST",
        "/admin/disputes/00000000-0000-0000-0000-000000000001/release",
    ),
    (
        "POST",
        "/admin/disputes/00000000-0000-0000-0000-000000000001/refund",
    ),
    ("GET", "/admin/unmatched-payments"),
    (
        "POST",
        "/admin/unmatched-payments/00000000-0000-0000-0000-000000000001/refund",
    ),
    (
        "POST",
        "/admin/unmatched-payments/00000000-0000-0000-0000-000000000001/dismiss",
    ),
];

async fn unreachable_db_state() -> AppState {
    let auth_url = spawn_mock_auth(HashMap::from([("user".to_string(), Uuid::new_v4())])).await;
    let pool = PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(500))
        .connect_lazy("postgres://postgres:postgres@127.0.0.1:1/unreachable")
        .unwrap();
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        rate_limits: Default::default(),
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    }
}

#[tokio::test]
async fn every_admin_route_requires_a_token() {
    let state = unreachable_db_state().await;
    for (method, path) in ROUTES {
        let body = (method == "POST").then(|| json!({ "note": "x" }));
        for token in [None, Some("forged")] {
            let (status, _) =
                send(&state, method.parse().unwrap(), path, token, body.clone()).await;
            assert_eq!(
                status,
                StatusCode::UNAUTHORIZED,
                "{method} {path} token={token:?}"
            );
        }
    }
}

#[tokio::test]
async fn admin_check_runs_before_anything_else() {
    // A signed-in user reaches the admin_users lookup, which fails here
    // because there is no database; nothing else in the handler runs.
    let state = unreachable_db_state().await;
    for (method, path) in ROUTES {
        let body = (method == "POST").then(|| json!({ "note": "" }));
        let (status, _) = send(&state, method.parse().unwrap(), path, Some("user"), body).await;
        assert_eq!(status, StatusCode::INTERNAL_SERVER_ERROR, "{method} {path}");
    }
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
            println!("Skipping admin DB integration test (needs a local DATABASE_URL)");
            return None;
        }
    };
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping admin DB integration test (cannot connect: {e})");
            None
        }
    }
}

struct World {
    state: AppState,
    fapshi: Fapshi,
    pool: PgPool,
    admin: Uuid,
    user: Uuid,
}

const ADMIN_TOKEN: &str = "admin";
const USER_TOKEN: &str = "user";

async fn world() -> Option<World> {
    let pool = test_db().await?;
    let admin = Uuid::new_v4();
    let user = Uuid::new_v4();
    sqlx::query("INSERT INTO auth.users (id, email) VALUES ($1, 'admin@test'), ($2, 'user@test')")
        .bind(admin)
        .bind(user)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO admin_users (user_id) VALUES ($1)")
        .bind(admin)
        .execute(&pool)
        .await
        .unwrap();
    for key in [
        "fapshi_disbursement_api_user",
        "fapshi_disbursement_api_key",
        "fapshi_collection_api_user",
        "fapshi_collection_api_key",
    ] {
        sqlx::query(
            "INSERT INTO app_secrets (key, value) VALUES ($1, 'test') ON CONFLICT DO NOTHING",
        )
        .bind(key)
        .execute(&pool)
        .await
        .unwrap();
    }
    let auth_url = spawn_mock_auth(HashMap::from([
        (ADMIN_TOKEN.to_string(), admin),
        (USER_TOKEN.to_string(), user),
    ]))
    .await;
    let fapshi: Fapshi = Arc::default();
    let fapshi_url = spawn_mock_fapshi(fapshi.clone()).await;
    let state = AppState {
        pool: pool.clone(),
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: fapshi_url,
        rate_limits: Default::default(),
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    };
    Some(World {
        state,
        fapshi,
        pool,
        admin,
        user,
    })
}

struct Sale {
    tx_id: Uuid,
    reference: String,
}

const SELLER_PHONE: &str = "699888777";
const PAYER_PHONE: &str = "677123456";

/// A 500 XAF sale whose transaction and escrow are both `status`.
async fn seed_sale(w: &World, status: &str, payer_phone: Option<&str>) -> Sale {
    let (seller, buyer) = (Uuid::new_v4(), Uuid::new_v4());
    let reference = format!("ref{}", Uuid::new_v4().simple());
    sqlx::query("INSERT INTO auth.users (id) VALUES ($1), ($2)")
        .bind(seller)
        .bind(buyer)
        .execute(&w.pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO profiles (id, full_name) VALUES ($1, 'Seller'), ($2, 'Buyer')")
        .bind(seller)
        .bind(buyer)
        .execute(&w.pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO profiles_private (id, whatsapp_number) VALUES ($1, $2)")
        .bind(seller)
        .bind(SELLER_PHONE)
        .execute(&w.pool)
        .await
        .unwrap();
    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id, status) \
         VALUES ('Test Book', 'Author', 500, 'good', $1, 'sold') RETURNING id",
    )
    .bind(seller)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    let tx_id: Uuid = sqlx::query_scalar(
        "INSERT INTO transactions (listing_id, buyer_id, seller_id, amount, commission_amount, payment_reference, status) \
         VALUES ($1, $2, $3, 500, 25, $4, $5) RETURNING id",
    )
    .bind(listing)
    .bind(buyer)
    .bind(seller)
    .bind(&reference)
    .bind(status)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO escrow_transactions (transaction_id, status, dispute_reason) VALUES ($1, $2, 'Book never arrived')",
    )
    .bind(tx_id)
    .bind(status)
    .execute(&w.pool)
    .await
    .unwrap();
    if let Some(phone) = payer_phone {
        record_payer(w, &reference, phone).await;
    }
    Sale { tx_id, reference }
}

/// Turns a seeded legacy sale into one made under the buyer-fee model (#30):
/// the buyer paid 500 + 30 and the seller is owed the full 500.
async fn with_buyer_fee(w: &World, sale: &Sale) {
    sqlx::query("UPDATE transactions SET buyer_fee = 30, commission_amount = 0 WHERE id = $1")
        .bind(sale.tx_id)
        .execute(&w.pool)
        .await
        .unwrap();
}

async fn record_payer(w: &World, reference: &str, phone: &str) {
    sqlx::query("INSERT INTO payment_payers (payment_reference, phone) VALUES ($1, $2)")
        .bind(reference)
        .bind(phone)
        .execute(&w.pool)
        .await
        .unwrap();
}

async fn statuses(w: &World, tx_id: Uuid) -> (String, String) {
    let row = sqlx::query(
        "SELECT t.status, e.status AS escrow FROM transactions t \
         JOIN escrow_transactions e ON e.transaction_id = t.id WHERE t.id = $1",
    )
    .bind(tx_id)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    (row.get("status"), row.get("escrow"))
}

async fn actions_for_tx(w: &World, tx_id: Uuid) -> Vec<(String, Option<String>, Uuid)> {
    sqlx::query(
        "SELECT action, payout_reference, admin_id FROM admin_actions WHERE transaction_id = $1",
    )
    .bind(tx_id)
    .fetch_all(&w.pool)
    .await
    .unwrap()
    .into_iter()
    .map(|r| {
        (
            r.get("action"),
            r.get("payout_reference"),
            r.get("admin_id"),
        )
    })
    .collect()
}

async fn seed_unmatched(w: &World, trans_id: &str) -> Uuid {
    sqlx::query_scalar(
        "INSERT INTO fapshi_audit_logs (endpoint, request_payload) \
         VALUES ('webhook/unmatched-payment', $1) RETURNING id",
    )
    .bind(json!({ "transId": trans_id, "amount": 300, "externalId": "purchase_x", "reason": "no pending transaction" }))
    .fetch_one(&w.pool)
    .await
    .unwrap()
}

fn note() -> Option<Value> {
    Some(json!({ "note": "Checked with both parties on WhatsApp" }))
}

#[tokio::test]
async fn non_admins_are_forbidden() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;

    let (status, _) = send(&w.state, Method::GET, "/admin/me", Some(USER_TOKEN), None).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    let path = format!("/admin/disputes/{}/refund", sale.tx_id);
    let (status, _) = send(&w.state, Method::POST, &path, Some(USER_TOKEN), note()).await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    assert!(w.fapshi.lock().unwrap().payouts.is_empty());
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("disputed".into(), "disputed".into())
    );
    let _ = w.user;
}

#[tokio::test]
async fn admin_me_and_dispute_list() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    let held = seed_sale(&w, "held", None).await;

    let (status, body) = send(&w.state, Method::GET, "/admin/me", Some(ADMIN_TOKEN), None).await;
    assert_eq!((status, body), (StatusCode::OK, json!({ "admin": true })));

    let (status, body) = send(
        &w.state,
        Method::GET,
        "/admin/disputes",
        Some(ADMIN_TOKEN),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let disputes = body["disputes"].as_array().unwrap();
    let ours = disputes
        .iter()
        .find(|d| d["transaction_id"] == json!(sale.tx_id))
        .expect("seeded dispute is listed");
    assert_eq!(ours["amount"], 500);
    assert_eq!(ours["listing_title"], "Test Book");
    assert_eq!(ours["dispute_reason"], "Book never arrived");
    assert_eq!(ours["payer_phone_hint"], "677•••456");
    assert!(
        !body.to_string().contains(PAYER_PHONE),
        "full payer number must not leak"
    );
    assert!(disputes
        .iter()
        .all(|d| d["transaction_id"] != json!(held.tx_id)));
}

#[tokio::test]
async fn refund_dispute_pays_the_payer_once() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    let path = format!("/admin/disputes/{}/refund", sale.tx_id);

    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["payout_reference"], "payout1");
    {
        let f = w.fapshi.lock().unwrap();
        assert_eq!(f.payouts.len(), 1);
        assert_eq!(f.payouts[0]["amount"], json!(500.0));
        assert_eq!(f.payouts[0]["phone"], PAYER_PHONE);
        assert_eq!(
            f.payouts[0]["externalId"],
            format!("escrow_refund_{}", sale.reference)
        );
    }
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("refunded".into(), "refunded".into())
    );
    assert_eq!(
        actions_for_tx(&w, sale.tx_id).await,
        vec![(
            "refund_dispute".to_string(),
            Some("payout1".to_string()),
            w.admin
        )]
    );

    // A second click is refused and pays nothing.
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(w.fapshi.lock().unwrap().payouts.len(), 1);
}

#[tokio::test]
async fn refund_dispute_reuses_a_payout_made_before_a_crash() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    w.fapshi.lock().unwrap().search.insert(
        format!("escrow_refund_{}", sale.reference),
        vec![json!({ "transId": "earlier", "status": "SUCCESSFUL", "externalId": format!("escrow_refund_{}", sale.reference) })],
    );

    let path = format!("/admin/disputes/{}/refund", sale.tx_id);
    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["payout_reference"], "earlier");
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("refunded".into(), "refunded".into())
    );
}

#[tokio::test]
async fn refund_dispute_waits_for_an_in_flight_payout() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    w.fapshi.lock().unwrap().search.insert(
        format!("escrow_refund_{}", sale.reference),
        vec![json!({ "transId": "inflight", "status": "PENDING", "externalId": format!("escrow_refund_{}", sale.reference) })],
    );

    let path = format!("/admin/disputes/{}/refund", sale.tx_id);
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("disputed".into(), "disputed".into())
    );
    assert!(actions_for_tx(&w, sale.tx_id).await.is_empty());
}

#[tokio::test]
async fn refund_dispute_needs_a_number() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", None).await;
    let path = format!("/admin/disputes/{}/refund", sale.tx_id);

    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    let bad = Some(json!({ "note": "n", "phone": "12345" }));
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), bad).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());

    let typed = Some(json!({ "note": "Buyer gave number by phone", "phone": "+237 655 000 111" }));
    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), typed).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(w.fapshi.lock().unwrap().payouts[0]["phone"], "655000111");
}

#[tokio::test]
async fn refund_and_release_only_apply_to_disputes() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "held", Some(PAYER_PHONE)).await;

    let path = format!("/admin/disputes/{}/refund", sale.tx_id);
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    let path = format!("/admin/disputes/{}/release", sale.tx_id);
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    let path = format!("/admin/disputes/{}/refund", Uuid::new_v4());
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    assert!(w.fapshi.lock().unwrap().payouts.is_empty());
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("held".into(), "held".into())
    );
}

#[tokio::test]
async fn release_dispute_pays_the_seller() {
    let Some(w) = world().await else { return };
    let sale = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    let path = format!("/admin/disputes/{}/release", sale.tx_id);

    let with_phone = Some(json!({ "note": "n", "phone": PAYER_PHONE }));
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), with_phone).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    let (status, _) = send(
        &w.state,
        Method::POST,
        &path,
        Some(ADMIN_TOKEN),
        Some(json!({ "note": " " })),
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());

    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    {
        let f = w.fapshi.lock().unwrap();
        assert_eq!(f.payouts.len(), 1);
        assert_eq!(f.payouts[0]["phone"], SELLER_PHONE);
        assert_eq!(f.payouts[0]["amount"], json!(475.0));
        assert_eq!(
            f.payouts[0]["externalId"],
            format!("escrow_payout_{}", sale.reference)
        );
    }
    assert_eq!(
        statuses(&w, sale.tx_id).await,
        ("successful".into(), "released".into())
    );
    assert_eq!(
        actions_for_tx(&w, sale.tx_id).await,
        vec![(
            "release_dispute".to_string(),
            Some("payout1".to_string()),
            w.admin
        )]
    );
}

#[tokio::test]
async fn unmatched_payment_refund() {
    let Some(w) = world().await else { return };
    let trans_id = format!("um{}", &Uuid::new_v4().simple().to_string()[..10]);
    let log_id = seed_unmatched(&w, &trans_id).await;
    record_payer(&w, &trans_id, PAYER_PHONE).await;

    let (status, body) = send(
        &w.state,
        Method::GET,
        "/admin/unmatched-payments",
        Some(ADMIN_TOKEN),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let listed = body["payments"]
        .as_array()
        .unwrap()
        .iter()
        .find(|p| p["id"] == json!(log_id))
        .cloned();
    let listed = listed.expect("unmatched payment is listed");
    assert_eq!(listed["trans_id"], trans_id);
    assert_eq!(listed["payer_phone_hint"], "677•••456");

    // Fapshi doesn't know it yet: nothing is paid.
    let path = format!("/admin/unmatched-payments/{log_id}/refund");
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::BAD_GATEWAY);
    w.fapshi.lock().unwrap().collections.insert(
        trans_id.clone(),
        json!({ "status": "FAILED", "amount": 300 }),
    );
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());

    // The amount refunded is Fapshi's, not the logged one.
    w.fapshi.lock().unwrap().collections.insert(
        trans_id.clone(),
        json!({ "status": "SUCCESSFUL", "amount": 250 }),
    );
    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    {
        let f = w.fapshi.lock().unwrap();
        assert_eq!(f.payouts.len(), 1);
        assert_eq!(f.payouts[0]["amount"], json!(250.0));
        assert_eq!(f.payouts[0]["phone"], PAYER_PHONE);
        assert_eq!(
            f.payouts[0]["externalId"],
            format!("unmatched_refund_{trans_id}")
        );
    }
    let action: (String, Option<String>) = sqlx::query_as(
        "SELECT action, payout_reference FROM admin_actions WHERE audit_log_id = $1",
    )
    .bind(log_id)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    assert_eq!(
        action,
        ("refund_unmatched".to_string(), Some("payout1".to_string()))
    );

    // Resolved: no longer listed, and can't be refunded or dismissed again.
    let (_, body) = send(
        &w.state,
        Method::GET,
        "/admin/unmatched-payments",
        Some(ADMIN_TOKEN),
        None,
    )
    .await;
    assert!(body["payments"]
        .as_array()
        .unwrap()
        .iter()
        .all(|p| p["id"] != json!(log_id)));
    let (status, _) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    let dismiss = format!("/admin/unmatched-payments/{log_id}/dismiss");
    let (status, _) = send(&w.state, Method::POST, &dismiss, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(w.fapshi.lock().unwrap().payouts.len(), 1);
}

#[tokio::test]
async fn unmatched_payment_dismiss() {
    let Some(w) = world().await else { return };
    let trans_id = format!("um{}", &Uuid::new_v4().simple().to_string()[..10]);
    let log_id = seed_unmatched(&w, &trans_id).await;
    let dismiss = format!("/admin/unmatched-payments/{log_id}/dismiss");

    let with_phone = Some(json!({ "note": "n", "phone": PAYER_PHONE }));
    let (status, _) = send(
        &w.state,
        Method::POST,
        &dismiss,
        Some(ADMIN_TOKEN),
        with_phone,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);

    let (status, _) = send(&w.state, Method::POST, &dismiss, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK);
    let (_, body) = send(
        &w.state,
        Method::GET,
        "/admin/unmatched-payments",
        Some(ADMIN_TOKEN),
        None,
    )
    .await;
    assert!(body["payments"]
        .as_array()
        .unwrap()
        .iter()
        .all(|p| p["id"] != json!(log_id)));

    let refund = format!("/admin/unmatched-payments/{log_id}/refund");
    let (status, _) = send(&w.state, Method::POST, &refund, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::CONFLICT);
    let missing = format!("/admin/unmatched-payments/{}/dismiss", Uuid::new_v4());
    let (status, _) = send(&w.state, Method::POST, &missing, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert!(w.fapshi.lock().unwrap().payouts.is_empty());
}

#[tokio::test]
async fn buyer_fee_is_refunded_and_seller_is_paid_in_full() {
    let Some(w) = world().await else { return };
    let refunded = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    with_buyer_fee(&w, &refunded).await;
    let released = seed_sale(&w, "disputed", Some(PAYER_PHONE)).await;
    with_buyer_fee(&w, &released).await;

    let (status, body) = send(
        &w.state,
        Method::GET,
        "/admin/disputes",
        Some(ADMIN_TOKEN),
        None,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    let listed = body["disputes"]
        .as_array()
        .unwrap()
        .iter()
        .find(|d| d["transaction_id"] == json!(refunded.tx_id))
        .expect("seeded dispute is listed")
        .clone();
    assert_eq!(listed["amount"], 530);

    let path = format!("/admin/disputes/{}/refund", refunded.tx_id);
    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    let path = format!("/admin/disputes/{}/release", released.tx_id);
    let (status, body) = send(&w.state, Method::POST, &path, Some(ADMIN_TOKEN), note()).await;
    assert_eq!(status, StatusCode::OK, "{body}");

    let f = w.fapshi.lock().unwrap();
    assert_eq!(f.payouts.len(), 2);
    assert_eq!(f.payouts[0]["phone"], PAYER_PHONE);
    assert_eq!(f.payouts[0]["amount"], json!(530.0));
    assert_eq!(f.payouts[1]["phone"], SELLER_PHONE);
    assert_eq!(f.payouts[1]["amount"], json!(500.0));
}
