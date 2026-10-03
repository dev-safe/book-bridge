use bookbridge_rust_core::routes::webhook::fapshi_webhook_handler;
use bookbridge_rust_core::AppState;
use axum::{routing::post, Router, body::Body, http::{Request, StatusCode}};
use sqlx::PgPool;
use uuid::Uuid;
use std::sync::Arc;
use std::sync::Mutex;
use std::collections::HashSet;
use tower::ServiceExt;

#[tokio::test]
async fn test_webhook_integration() -> Result<(), Box<dyn std::error::Error>> {
    let _ = dotenvy::dotenv();
    
    // Safety check: only run on local test databases
    let db_url = match std::env::var("DATABASE_URL") {
        Ok(url) if (url.contains("localhost") || url.contains("127.0.0.1") || url.contains("test") || url.contains("dev"))
                   && !url.contains("pooler.supabase.com") 
                   && !url.contains("db.jacnsvcwmhoicuuzmrmr") => url,
        _ => {
            println!("Skipping webhook DB integration tests (non-local DATABASE_URL)");
            return Ok(());
        }
    };

    let pool = match PgPool::connect(&db_url).await {
        Ok(p) => p,
        Err(e) => {
            println!("Skipping webhook DB integration tests (connection failed: {})", e);
            return Ok(());
        }
    };

    // Setup mock rows in a transaction, then commit
    let mut tx = pool.begin().await?;

    let seller_id = Uuid::new_v4();
    let buyer_id = Uuid::new_v4();
    let listing_id = Uuid::new_v4();
    let transaction_id = Uuid::new_v4();
    let payment_ref = format!("web_test_ref_{}", Uuid::new_v4().to_string().replace("-", ""));

    // Mock auth users
    let user_setup = sqlx::query(
        "INSERT INTO auth.users (id, email) VALUES ($1, $2), ($3, $4)"
    )
    .bind(seller_id)
    .bind("wh-seller@example.com")
    .bind(buyer_id)
    .bind("wh-buyer@example.com")
    .execute(&mut *tx)
    .await;

    if let Err(e) = user_setup {
        println!("Skipping webhook DB check (cannot insert dummy auth.users: {}).", e);
        tx.rollback().await?;
        return Ok(());
    }

    // Profiles
    sqlx::query("INSERT INTO profiles (id, full_name) VALUES ($1, $2), ($3, $4)")
        .bind(seller_id).bind("Webhook Seller")
        .bind(buyer_id).bind("Webhook Buyer")
        .execute(&mut *tx).await?;
    sqlx::query("INSERT INTO profiles_private (id, whatsapp_number) VALUES ($1, $2)")
        .bind(seller_id).bind("+237612345678")
        .execute(&mut *tx).await?;

    // Listing
    sqlx::query("INSERT INTO listings (id, seller_id, title, status, author, price_fcfa, condition) VALUES ($1, $2, $3, $4, 'Author', 500, 'good')")
        .bind(listing_id).bind(seller_id).bind("Webhook Book").bind("active")
        .execute(&mut *tx).await?;

    // Initial Transaction in pending_payment state
    sqlx::query(
        "INSERT INTO transactions (id, listing_id, buyer_id, seller_id, amount, status, payout_status, payment_reference) \
         VALUES ($1, $2, $3, $4, 5000, 'pending_payment', 'pending', $5)"
    )
    .bind(transaction_id)
    .bind(listing_id)
    .bind(buyer_id)
    .bind(seller_id)
    .bind(&payment_ref)
    .execute(&mut *tx)
    .await?;

    // App secrets for webhook authentication
    sqlx::query(
        "INSERT INTO app_secrets (key, value) VALUES ($1, $2), ($3, $4), ($5, $6) \
         ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value"
    )
    .bind("fapshi_collection_webhook_secret").bind("wh_test_key_xyz")
    .bind("fapshi_collection_api_user").bind("wh_test_payout_user")
    .bind("fapshi_collection_api_key").bind("wh_test_payout_key")
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    // Initialize State
    let state = AppState {
        pool: pool.clone(),
        in_progress_payouts: Arc::new(Mutex::new(HashSet::new())),
        fapshi_base_url: "http://127.0.0.1:1".to_string(),
        rate_limits: Default::default(),
        supabase_auth: bookbridge_rust_core::user_auth::SupabaseAuth::new("http://127.0.0.1:1", "test-anon-key"),
    };

    let app = Router::new()
        .route("/webhooks/fapshi", post(fapshi_webhook_handler))
        .with_state(state);

    // --- TEST CASE 1: Unauthorized Webhook (Invalid Key) ---
    {
        let payload = serde_json::json!({
            "status": "SUCCESSFUL",
            "transId": "fapshi_tx_111",
            "amount": 5000,
            "externalId": format!("purchase:{}:{}", listing_id, buyer_id)
        });
        
        let req = Request::builder()
            .method("POST")
            .uri("/webhooks/fapshi")
            .header("Content-Type", "application/json")
            .header("x-wh-secret", "invalid_secret")
            .body(Body::from(serde_json::to_string(&payload)?))
            .unwrap();

        let response = app.clone().oneshot(req).await.unwrap();
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    }

    // --- TEST CASE 2: Malformed Payload (400 Bad Request) ---
    {
        let req = Request::builder()
            .method("POST")
            .uri("/webhooks/fapshi")
            .header("Content-Type", "application/json")
            .header("x-wh-secret", "wh_test_key_xyz")
            .body(Body::from("{ malformed json }"))
            .unwrap();

        let response = app.clone().oneshot(req).await.unwrap();
        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    }

    // --- TEST CASE 3: Successful Purchase Webhook ---
    {
        // Target the standard reference we setup
        let mock_payload = serde_json::json!([{
            "status": "SUCCESSFUL",
            "transId": &payment_ref, // Use the payment_reference as Fapshi transId
            "amount": "5000",
            "externalId": format!("purchase:{}:{}", listing_id, buyer_id)
        }]);

        let req = Request::builder()
            .method("POST")
            .uri("/webhooks/fapshi")
            .header("Content-Type", "application/json")
            .header("x-wh-secret", "wh_test_key_xyz")
            .body(Body::from(serde_json::to_string(&mock_payload)?))
            .unwrap();

        let response = app.clone().oneshot(req).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        // Verify database updates
        let tx_state: (String, String) = sqlx::query_as("SELECT status, payout_status FROM transactions WHERE id = $1")
            .bind(transaction_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(tx_state.0, "held");
        assert_eq!(tx_state.1, "pending");

        let listing_state: (String,) = sqlx::query_as("SELECT status FROM listings WHERE id = $1")
            .bind(listing_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(listing_state.0, "sold");

        let escrow_count: (i64,) = sqlx::query_as("SELECT count(*) FROM escrow_transactions WHERE transaction_id = $1")
            .bind(transaction_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(escrow_count.0, 1);

        let msg_count: (i64,) = sqlx::query_as("SELECT count(*) FROM messages WHERE listing_id = $1")
            .bind(listing_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(msg_count.0, 1);
    }

    // --- TEST CASE 4: Duplicate Webhook Delivery (No-op check) ---
    {
        // Re-deliver same success payload
        let mock_payload = serde_json::json!([{
            "status": "SUCCESSFUL",
            "transId": &payment_ref,
            "amount": "5000",
            "externalId": format!("purchase:{}:{}", listing_id, buyer_id)
        }]);

        let req = Request::builder()
            .method("POST")
            .uri("/webhooks/fapshi")
            .header("Content-Type", "application/json")
            .header("x-wh-secret", "wh_test_key_xyz")
            .body(Body::from(serde_json::to_string(&mock_payload)?))
            .unwrap();

        let response = app.clone().oneshot(req).await.unwrap();
        assert_eq!(response.status(), StatusCode::OK);

        // Verify no duplicates were created
        let escrow_count: (i64,) = sqlx::query_as("SELECT count(*) FROM escrow_transactions WHERE transaction_id = $1")
            .bind(transaction_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(escrow_count.0, 1); // Remains exactly 1 (no duplicate row)

        let msg_count: (i64,) = sqlx::query_as("SELECT count(*) FROM messages WHERE listing_id = $1")
            .bind(listing_id)
            .fetch_one(&pool)
            .await?;
        assert_eq!(msg_count.0, 1); // Remains exactly 1
    }

    // Manual database cleanup
    let _ = sqlx::query("DELETE FROM app_secrets WHERE key IN ('fapshi_collection_webhook_secret', 'fapshi_collection_api_user', 'fapshi_collection_api_key')").execute(&pool).await;
    let _ = sqlx::query("DELETE FROM messages WHERE listing_id = $1").bind(listing_id).execute(&pool).await;
    let _ = sqlx::query("DELETE FROM escrow_transactions WHERE transaction_id = $1").bind(transaction_id).execute(&pool).await;
    let _ = sqlx::query("DELETE FROM transactions WHERE id = $1").bind(transaction_id).execute(&pool).await;
    let _ = sqlx::query("DELETE FROM listings WHERE id = $1").bind(listing_id).execute(&pool).await;
    let _ = sqlx::query("DELETE FROM profiles WHERE id IN ($1, $2)").bind(seller_id).bind(buyer_id).execute(&pool).await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id IN ($1, $2)").bind(seller_id).bind(buyer_id).execute(&pool).await;

    Ok(())
}
