//! Account deletion (`POST /account/delete`).
//!
//! Supabase Auth and Storage are replaced by a local mock. Tests that need a
//! database run only when `DATABASE_URL` points at a local/test Postgres
//! loaded with `tests/fixtures/production_schema.sql` plus the migrations
//! newer than it; otherwise they print a skip notice and pass.

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header::AUTHORIZATION, HeaderMap, Request, StatusCode},
    response::IntoResponse,
    routing::{delete, get, post},
    Json, Router,
};
use bookbridge_rust_core::{
    routes::account::{account_routes, ACTIVE_ORDERS_MESSAGE, DELETED_USER_NAME, USER_BUCKETS},
    user_auth::SupabaseAuth,
    AppState,
};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, PgPool, Row};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

const ANON_KEY: &str = "test-anon-key";
const TOKEN: &str = "user-token";

// ---------------------------------------------------------------- mocks

/// Mock Storage: objects per bucket. `fail` makes every call error;
/// `undeletable` buckets ignore deletes, like an RLS policy that hides
/// objects from the token.
#[derive(Default)]
struct MockStorage {
    objects: HashMap<String, BTreeSet<String>>,
    undeletable: HashSet<String>,
    fail: bool,
}

impl MockStorage {
    fn add(&mut self, bucket: &str, path: &str) {
        self.objects
            .entry(bucket.to_string())
            .or_default()
            .insert(path.to_string());
    }

    fn in_folder(&self, bucket: &str, folder: &str) -> Vec<String> {
        let prefix = format!("{folder}/");
        self.objects
            .get(bucket)
            .map(|set| {
                set.iter()
                    .filter(|p| p.starts_with(&prefix))
                    .cloned()
                    .collect()
            })
            .unwrap_or_default()
    }
}

type Storage = Arc<Mutex<MockStorage>>;

#[derive(Clone)]
struct Mock {
    tokens: Arc<HashMap<String, Uuid>>,
    storage: Storage,
}

impl Mock {
    fn authorised(&self, headers: &HeaderMap) -> Option<Uuid> {
        if !headers.get("apikey").is_some_and(|v| v == ANON_KEY) {
            return None;
        }
        headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .and_then(|t| self.tokens.get(t))
            .copied()
    }
}

async fn user_handler(State(mock): State<Mock>, headers: HeaderMap) -> impl IntoResponse {
    match mock.authorised(&headers) {
        Some(id) => Json(json!({ "id": id })).into_response(),
        None => StatusCode::UNAUTHORIZED.into_response(),
    }
}

async fn list_handler(
    State(mock): State<Mock>,
    Path(bucket): Path<String>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> impl IntoResponse {
    if mock.authorised(&headers).is_none() {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    let s = mock.storage.lock().unwrap();
    if s.fail {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    }
    let folder = body["prefix"].as_str().unwrap_or_default();
    let mut entries: Vec<Value> = s
        .in_folder(&bucket, folder)
        .iter()
        .map(|p| json!({ "name": p.rsplit('/').next().unwrap(), "id": Uuid::new_v4() }))
        .collect();
    // A sub-folder entry, which Storage returns with a null id.
    entries.push(json!({ "name": "nested", "id": null }));
    Json(entries).into_response()
}

async fn delete_handler(
    State(mock): State<Mock>,
    Path(bucket): Path<String>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> impl IntoResponse {
    if mock.authorised(&headers).is_none() {
        return StatusCode::UNAUTHORIZED.into_response();
    }
    let mut s = mock.storage.lock().unwrap();
    if s.fail {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    }
    if s.undeletable.contains(&bucket) {
        return Json(json!([])).into_response();
    }
    let prefixes: Vec<String> = body["prefixes"]
        .as_array()
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    if let Some(set) = s.objects.get_mut(&bucket) {
        for p in &prefixes {
            set.remove(p);
        }
    }
    Json(json!([])).into_response()
}

async fn spawn_mock_supabase(tokens: HashMap<String, Uuid>, storage: Storage) -> String {
    let mock = Mock {
        tokens: Arc::new(tokens),
        storage,
    };
    let app = Router::new()
        .route("/auth/v1/user", get(user_handler))
        .route("/storage/v1/object/list/:bucket", post(list_handler))
        .route("/storage/v1/object/:bucket", delete(delete_handler))
        .with_state(mock);
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    format!("http://{addr}")
}

fn state_with(pool: PgPool, auth_url: String) -> AppState {
    AppState {
        pool,
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        push: Default::default(),
        rate_limits: Default::default(),
        supabase_auth: SupabaseAuth::new(auth_url, ANON_KEY),
    }
}

async fn delete_account(state: &AppState, token: Option<&str>) -> (StatusCode, Value) {
    let mut req = Request::builder().method("POST").uri("/account/delete");
    if let Some(token) = token {
        req = req.header(AUTHORIZATION, format!("Bearer {token}"));
    }
    let res = account_routes()
        .with_state(state.clone())
        .oneshot(req.body(Body::empty()).unwrap())
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

// ------------------------------------------------------------ no database

#[tokio::test]
async fn deletion_requires_a_valid_token() {
    let auth_url = spawn_mock_supabase(
        HashMap::from([(TOKEN.to_string(), Uuid::new_v4())]),
        Storage::default(),
    )
    .await;
    let pool = PgPoolOptions::new()
        .acquire_timeout(Duration::from_millis(500))
        .connect_lazy("postgres://postgres@127.0.0.1:1/unreachable")
        .unwrap();
    let state = state_with(pool, auth_url);
    for token in [None, Some("forged")] {
        let (status, _) = delete_account(&state, token).await;
        assert_eq!(status, StatusCode::UNAUTHORIZED, "token {token:?}");
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
            println!("Skipping account DB integration test (needs a local DATABASE_URL)");
            return None;
        }
    };
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping account DB integration test (cannot connect: {e})");
            None
        }
    }
}

/// A user about to delete their account, a buyer they traded with, and the
/// rows that connect them.
struct World {
    state: AppState,
    storage: Storage,
    pool: PgPool,
    user: Uuid,
    other: Uuid,
    /// The user's listing nothing points at.
    free_listing: Uuid,
    /// The user's listing the other user bought (kept for the record).
    sold_listing: Uuid,
    /// The other user's listing.
    other_listing: Uuid,
    sale: Uuid,
}

async fn exec(pool: &PgPool, sql: &str, args: &[Uuid]) {
    let mut q = sqlx::query(sql);
    for a in args {
        q = q.bind(*a);
    }
    q.execute(pool).await.unwrap();
}

async fn add_user(pool: &PgPool, id: Uuid, name: &str) {
    exec(
        pool,
        "INSERT INTO auth.users (id, email, phone, encrypted_password, raw_user_meta_data) \
         VALUES ($1, $1::text || '@test', '670000000', 'hash', '{\"full_name\": \"x\"}')",
        &[id],
    )
    .await;
    sqlx::query(
        "INSERT INTO profiles (id, email, full_name, locality, whatsapp_number, avatar_url, \
                               fcm_token, date_of_birth, id_verification_status, id_type, \
                               guardian_phone, id_document_paths, age_declaration) \
         VALUES ($1, 'x@test', $2, 'Bamenda', '670000000', 'https://x/avatar.jpg', 'fcm', \
                 '2012-01-01', 'pending', 'school_id', '670000001', ARRAY[$1::text || '/id.jpg'], \
                 'guardian')",
    )
    .bind(id)
    .bind(name)
    .execute(pool)
    .await
    .unwrap();
    exec(
        pool,
        "INSERT INTO profiles_private (id, whatsapp_number, fcm_token) VALUES ($1, '670000000', 'fcm') \
         ON CONFLICT (id) DO NOTHING",
        &[id],
    )
    .await;
}

async fn add_listing(pool: &PgPool, seller: Uuid, status: &str) -> Uuid {
    sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id, status, \
                               image_url, image_urls, description, latitude, longitude, meetup_spot) \
         VALUES ('Book', 'Author', 2000, 'good', $1, $2, 'https://x/1.jpg', \
                 ARRAY['https://x/1.jpg'], 'desc', 5.9, 10.1, 'Main gate') \
         RETURNING id",
    )
    .bind(seller)
    .bind(status)
    .fetch_one(pool)
    .await
    .unwrap()
}

async fn add_transaction(
    pool: &PgPool,
    listing: Uuid,
    buyer: Uuid,
    seller: Uuid,
    status: &str,
) -> Uuid {
    sqlx::query_scalar(
        "INSERT INTO transactions (listing_id, buyer_id, seller_id, amount, payment_reference, status) \
         VALUES ($1, $2, $3, 2000, $4, $5) RETURNING id",
    )
    .bind(listing)
    .bind(buyer)
    .bind(seller)
    .bind(format!("ref_{}", Uuid::new_v4().simple()))
    .bind(status)
    .fetch_one(pool)
    .await
    .unwrap()
}

async fn world() -> Option<World> {
    let pool = test_db().await?;
    let user = Uuid::new_v4();
    let other = Uuid::new_v4();
    add_user(&pool, user, "Leaving User").await;
    add_user(&pool, other, "Staying User").await;

    let free_listing = add_listing(&pool, user, "available").await;
    let sold_listing = add_listing(&pool, user, "sold").await;
    let other_listing = add_listing(&pool, other, "available").await;
    // The user sold a book to the other user, and bought one from them.
    let sale = add_transaction(&pool, sold_listing, other, user, "successful").await;
    let purchase = add_transaction(&pool, other_listing, user, other, "successful").await;
    sqlx::query(
        "INSERT INTO payment_payers (payment_reference, phone) \
         SELECT payment_reference, '670000000' FROM transactions WHERE id = ANY($1)",
    )
    .bind(vec![sale, purchase])
    .execute(&pool)
    .await
    .unwrap();

    exec(
        &pool,
        "INSERT INTO reviews (reviewer_id, reviewee_id, listing_id, transaction_id, rating, comment) \
         VALUES ($1, $2, $3, $4, 5, 'Great seller, call me on 670000000'), \
                ($2, $1, $5, $6, 4, 'Smooth sale')",
        &[user, other, other_listing, purchase, sold_listing, sale],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO messages (listing_id, sender_id, receiver_id, content) \
         VALUES ($3, $1, $2, 'hi'), ($3, $2, $1, 'hello'), ($4, $2, $2, 'note to self')",
        &[user, other, other_listing, other_listing],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO favorites (user_id, listing_id) VALUES ($1, $3), ($2, $4)",
        &[user, other, other_listing, free_listing],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO wishlists (user_id, listing_id) VALUES ($1, $2)",
        &[user, other_listing],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO notifications (user_id, title, body) VALUES ($1, 't', 'b'), ($2, 't', 'b')",
        &[user, other],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO feedback (user_id, content) VALUES ($1, 'Love the app')",
        &[user],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO donations (user_id, amount, payment_reference, status) \
         VALUES ($1, 500, 'don_' || $1::text, 'successful')",
        &[user],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO auth.identities (user_id) VALUES ($1), ($2)",
        &[user, other],
    )
    .await;
    for table in ["sessions", "mfa_factors", "one_time_tokens"] {
        exec(
            &pool,
            &format!("INSERT INTO auth.{table} (user_id) VALUES ($1), ($2)"),
            &[user, other],
        )
        .await;
    }
    sqlx::query("INSERT INTO auth.refresh_tokens (user_id) VALUES ($1), ($2)")
        .bind(user.to_string())
        .bind(other.to_string())
        .execute(&pool)
        .await
        .unwrap();

    // Blocks both ways (after the messages, which a block would refuse) and
    // reports in both directions.
    exec(
        &pool,
        "INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2), ($2, $1)",
        &[user, other],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO content_reports (reporter_id, listing_id, reason) VALUES ($1, $2, 'spam')",
        &[user, other_listing],
    )
    .await;
    exec(
        &pool,
        "INSERT INTO content_reports (reporter_id, reported_user_id, reason) \
         VALUES ($1, $2, 'harassment')",
        &[other, user],
    )
    .await;

    let storage = Storage::default();
    {
        let mut s = storage.lock().unwrap();
        for bucket in USER_BUCKETS {
            s.add(bucket, &format!("{user}/a.jpg"));
            s.add(bucket, &format!("{user}/b.jpg"));
            s.add(bucket, &format!("{other}/a.jpg"));
        }
    }
    let auth_url =
        spawn_mock_supabase(HashMap::from([(TOKEN.to_string(), user)]), storage.clone()).await;

    Some(World {
        state: state_with(pool.clone(), auth_url),
        storage,
        pool,
        user,
        other,
        free_listing,
        sold_listing,
        other_listing,
        sale,
    })
}

async fn count(pool: &PgPool, sql: &str, id: Uuid) -> i64 {
    sqlx::query_scalar(sql)
        .bind(id)
        .fetch_one(pool)
        .await
        .unwrap()
}

async fn full_name(pool: &PgPool, id: Uuid) -> Option<String> {
    sqlx::query_scalar("SELECT full_name FROM profiles WHERE id = $1")
        .bind(id)
        .fetch_one(pool)
        .await
        .unwrap()
}

fn user_files(w: &World) -> usize {
    let s = w.storage.lock().unwrap();
    USER_BUCKETS
        .iter()
        .map(|b| s.in_folder(b, &w.user.to_string()).len())
        .sum()
}

/// Nothing was written and no file was deleted.
async fn assert_untouched(w: &World) {
    assert_eq!(
        full_name(&w.pool, w.user).await.as_deref(),
        Some("Leaving User")
    );
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM auth.sessions WHERE user_id = $1",
            w.user
        )
        .await,
        1
    );
    assert_eq!(user_files(w), 6);
}

#[tokio::test]
async fn deletion_anonymises_the_account_and_keeps_order_history() {
    let Some(w) = world().await else { return };

    let (status, body) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(status, StatusCode::OK, "{body}");
    assert_eq!(body["ok"], true);

    // Profile anonymised.
    let p = sqlx::query(
        "SELECT full_name, email, locality, whatsapp_number, avatar_url, fcm_token, \
                date_of_birth IS NULL AS no_dob, guardian_phone, id_type, \
                id_document_paths, id_verification_status, age_declaration \
         FROM profiles WHERE id = $1",
    )
    .bind(w.user)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    assert_eq!(p.get::<String, _>("full_name"), DELETED_USER_NAME);
    for col in [
        "email",
        "locality",
        "whatsapp_number",
        "avatar_url",
        "fcm_token",
        "guardian_phone",
        "id_type",
        "age_declaration",
    ] {
        assert!(
            p.get::<Option<String>, _>(col).is_none(),
            "{col} not cleared"
        );
    }
    assert!(p.get::<bool, _>("no_dob"));
    assert!(p.get::<Vec<String>, _>("id_document_paths").is_empty());
    assert_eq!(p.get::<String, _>("id_verification_status"), "unverified");

    // Personal rows gone.
    for sql in [
        "SELECT count(*) FROM profiles_private WHERE id = $1",
        "SELECT count(*) FROM messages WHERE sender_id = $1 OR receiver_id = $1",
        "SELECT count(*) FROM favorites WHERE user_id = $1",
        "SELECT count(*) FROM wishlists WHERE user_id = $1",
        "SELECT count(*) FROM notifications WHERE user_id = $1",
        "SELECT count(*) FROM feedback WHERE user_id = $1",
        "SELECT count(*) FROM user_blocks WHERE blocker_id = $1 OR blocked_id = $1",
        "SELECT count(*) FROM content_reports WHERE reporter_id = $1 OR reported_user_id = $1",
        "SELECT count(*) FROM payment_payers pp JOIN transactions t \
           ON t.payment_reference = pp.payment_reference WHERE t.buyer_id = $1",
    ] {
        assert_eq!(count(&w.pool, sql, w.user).await, 0, "{sql}");
    }

    // Listings: the unreferenced one is deleted, the sold one kept bare.
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM listings WHERE id = $1",
            w.free_listing
        )
        .await,
        0
    );
    let l = sqlx::query(
        "SELECT status, image_url, image_urls, description, latitude, meetup_spot \
         FROM listings WHERE id = $1",
    )
    .bind(w.sold_listing)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    assert_eq!(l.get::<String, _>("status"), "sold");
    assert!(l.get::<Option<String>, _>("image_url").is_none());
    assert!(l.get::<Vec<String>, _>("image_urls").is_empty());
    assert!(l.get::<Option<String>, _>("description").is_none());
    assert!(l.get::<Option<f64>, _>("latitude").is_none());
    assert!(l.get::<Option<String>, _>("meetup_spot").is_none());

    // Orders, ratings and financial records kept.
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM transactions WHERE buyer_id = $1 OR seller_id = $1",
            w.user
        )
        .await,
        2
    );
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM transactions WHERE id = $1",
            w.sale
        )
        .await,
        1
    );
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM donations WHERE user_id = $1",
            w.user
        )
        .await,
        1
    );
    let review: (i16, Option<String>) =
        sqlx::query_as("SELECT rating, comment FROM reviews WHERE reviewer_id = $1")
            .bind(w.user)
            .fetch_one(&w.pool)
            .await
            .unwrap();
    assert_eq!(review, (5, None));
    // Reports kept for moderation history, without the deleted user.
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM content_reports WHERE listing_id = $1 AND reporter_id IS NULL",
            w.other_listing
        )
        .await,
        1
    );
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM content_reports WHERE reporter_id = $1 \
               AND reported_user_id IS NULL",
            w.other
        )
        .await,
        1
    );

    // Login scrubbed and banned.
    let u = sqlx::query(
        "SELECT email, phone, encrypted_password, raw_user_meta_data::text AS meta, \
                banned_until > now() + interval '99 years' AS banned, \
                deleted_at IS NOT NULL AS deleted \
         FROM auth.users WHERE id = $1",
    )
    .bind(w.user)
    .fetch_one(&w.pool)
    .await
    .unwrap();
    assert!(u.get::<Option<String>, _>("email").is_none());
    assert!(u.get::<Option<String>, _>("phone").is_none());
    assert_eq!(
        u.get::<Option<String>, _>("encrypted_password").as_deref(),
        Some("")
    );
    assert_eq!(u.get::<String, _>("meta"), "{}");
    assert!(u.get::<bool, _>("banned"));
    assert!(u.get::<bool, _>("deleted"));
    for table in ["identities", "sessions", "mfa_factors", "one_time_tokens"] {
        let sql = format!("SELECT count(*) FROM auth.{table} WHERE user_id = $1");
        assert_eq!(count(&w.pool, &sql, w.user).await, 0, "auth.{table}");
    }
    let refresh: i64 =
        sqlx::query_scalar("SELECT count(*) FROM auth.refresh_tokens WHERE user_id = $1")
            .bind(w.user.to_string())
            .fetch_one(&w.pool)
            .await
            .unwrap();
    assert_eq!(refresh, 0);

    // Files gone from every bucket.
    assert_eq!(user_files(&w), 0);

    // The other user is untouched. (Message triggers may have added
    // notifications, so only presence is checked.)
    assert_eq!(
        full_name(&w.pool, w.other).await.as_deref(),
        Some("Staying User")
    );
    for sql in [
        "SELECT count(*) FROM auth.sessions WHERE user_id = $1",
        "SELECT count(*) FROM profiles_private WHERE id = $1",
        "SELECT count(*) FROM notifications WHERE user_id = $1",
        "SELECT count(*) FROM messages WHERE sender_id = $1 AND receiver_id = $1",
        "SELECT count(*) FROM listings WHERE seller_id = $1 AND status = 'available' \
           AND image_url IS NOT NULL",
    ] {
        assert!(count(&w.pool, sql, w.other).await >= 1, "{sql}");
    }
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM reviews WHERE reviewer_id = $1 AND comment IS NOT NULL",
            w.other
        )
        .await,
        1
    );
    let s = w.storage.lock().unwrap();
    for bucket in USER_BUCKETS {
        assert_eq!(
            s.in_folder(bucket, &w.other.to_string()).len(),
            1,
            "{bucket}"
        );
    }
}

#[tokio::test]
async fn deletion_is_refused_while_an_order_is_open() {
    for (status, as_seller) in [
        ("pending_payment", false),
        ("held", true),
        ("disputed", false),
        ("pending", true),
    ] {
        let Some(w) = world().await else { return };
        let (buyer, seller, listing) = if as_seller {
            (w.other, w.user, w.free_listing)
        } else {
            (w.user, w.other, w.other_listing)
        };
        add_transaction(&w.pool, listing, buyer, seller, status).await;

        let (code, body) = delete_account(&w.state, Some(TOKEN)).await;
        assert_eq!(code, StatusCode::CONFLICT, "{status}");
        assert_eq!(body["error"], ACTIVE_ORDERS_MESSAGE, "{status}");
        assert_untouched(&w).await;
    }
}

#[tokio::test]
async fn deletion_is_refused_while_escrow_is_held() {
    let Some(w) = world().await else { return };
    exec(
        &w.pool,
        "INSERT INTO escrow_transactions (transaction_id, status) VALUES ($1, 'held')",
        &[w.sale],
    )
    .await;

    let (code, _) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(code, StatusCode::CONFLICT);
    assert_untouched(&w).await;
}

#[tokio::test]
async fn deletion_is_refused_while_a_payment_is_reserved() {
    let Some(w) = world().await else { return };
    // Another buyer is mid-payment on the user's listing.
    exec(
        &w.pool,
        "INSERT INTO listing_reservations (listing_id, buyer_id, reserved_until) \
         VALUES ($1, $2, now() + interval '10 minutes')",
        &[w.free_listing, w.other],
    )
    .await;

    let (code, _) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(code, StatusCode::CONFLICT);
    assert_untouched(&w).await;

    // An expired reservation no longer blocks.
    exec(
        &w.pool,
        "UPDATE listing_reservations SET reserved_until = now() - interval '1 minute' \
         WHERE listing_id = $1",
        &[w.free_listing],
    )
    .await;
    let (code, _) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(code, StatusCode::OK);
}

#[tokio::test]
async fn nothing_is_written_when_storage_fails() {
    let Some(w) = world().await else { return };
    w.storage.lock().unwrap().fail = true;

    let (code, _) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(code, StatusCode::BAD_GATEWAY);
    w.storage.lock().unwrap().fail = false;
    assert_untouched(&w).await;
}

#[tokio::test]
async fn nothing_is_written_when_files_survive_the_delete() {
    let Some(w) = world().await else { return };
    // e.g. the id-documents owner-delete policy is missing.
    w.storage
        .lock()
        .unwrap()
        .undeletable
        .insert("id-documents".to_string());

    let (code, body) = delete_account(&w.state, Some(TOKEN)).await;
    assert_eq!(code, StatusCode::BAD_GATEWAY, "{body}");
    assert_eq!(
        full_name(&w.pool, w.user).await.as_deref(),
        Some("Leaving User")
    );
    assert_eq!(
        count(
            &w.pool,
            "SELECT count(*) FROM auth.sessions WHERE user_id = $1",
            w.user
        )
        .await,
        1
    );
}
