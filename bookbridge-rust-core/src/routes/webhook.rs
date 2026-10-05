use axum::{extract::State, http::HeaderMap, response::IntoResponse, Json};
use serde::{Deserialize, Serialize};
use crate::error::AppError;
use crate::auth::constant_time_compare;
use crate::routes::escrow::{handle_purchase_success_db, PurchaseOutcome};
use crate::routes::payments::{
    buyer_fee_for, covers_expected, parse_external_ref, ExternalRef, BOOST_DAYS, BOOST_PRICE_XAF,
    SUBSCRIPTION_DAYS, SUBSCRIPTION_PRICE_XAF,
};
use crate::AppState;
use sqlx::{PgPool, Row};
use uuid::Uuid;
use chrono::Utc;

#[derive(Deserialize, Serialize, Debug)]
pub struct FapshiWebhookPayload {
    pub status: Option<String>,
    pub state: Option<String>,
    #[serde(rename = "transId")]
    pub trans_id: Option<String>,
    #[serde(rename = "transactionId")]
    pub transaction_id: Option<String>,
    pub id: Option<String>,
    pub amount: Option<serde_json::Value>,
    #[serde(rename = "externalId")]
    pub external_id: Option<String>,
    #[serde(rename = "externalReference")]
    pub external_reference: Option<String>,
    pub custom: Option<String>,
}

async fn verify_webhook_auth(pool: &PgPool, headers: &HeaderMap) -> Result<(), AppError> {
    // A. Check x-wh-secret header (dashboard verification key)
    if let Some(wh_secret_header) = headers.get("x-wh-secret").and_then(|h| h.to_str().ok()) {
        let secret_row: Option<(String,)> = sqlx::query_as("SELECT value FROM app_secrets WHERE key = 'fapshi_collection_webhook_secret'")
            .fetch_optional(pool)
            .await?;
        
        if let Some(row) = secret_row {
            if constant_time_compare(wh_secret_header.as_bytes(), row.0.as_bytes()) {
                return Ok(());
            }
        }
    }

    let header_names: Vec<&str> = headers.keys().map(|k| k.as_str()).collect();
    tracing::warn!(
        "Unauthorized webhook request: invalid credentials. Header names: {:?}",
        header_names
    );
    Err(AppError::Unauthorized("Invalid authentication credentials".to_string()))
}

fn parse_purchase_ref(external_ref: &str) -> Result<(Uuid, Uuid), AppError> {
    let separator = if external_ref.contains(':') { ':' } else { '_' };
    let parts: Vec<&str> = external_ref.split(separator).collect();
    if parts.len() < 3 {
        return Err(AppError::BadRequest("Malformed external_reference for purchase".to_string()));
    }
    let listing_id = Uuid::parse_str(parts[1])
        .map_err(|_| AppError::BadRequest("Invalid listing_id UUID".to_string()))?;
    let buyer_id = Uuid::parse_str(parts[2])
        .map_err(|_| AppError::BadRequest("Invalid buyer_id UUID".to_string()))?;
    Ok((listing_id, buyer_id))
}

fn parse_boost_ref(external_ref: &str) -> Result<(Uuid, i32), AppError> {
    let separator = if external_ref.contains(':') { ':' } else { '_' };
    let parts: Vec<&str> = external_ref.split(separator).collect();
    if parts.len() < 2 {
        return Err(AppError::BadRequest("Malformed external_reference for boost".to_string()));
    }
    let listing_id = Uuid::parse_str(parts[1])
        .map_err(|_| AppError::BadRequest("Invalid listing_id UUID".to_string()))?;
    let duration = if parts.len() >= 3 {
        parts[2].parse::<i32>().unwrap_or(7)
    } else {
        7
    };
    Ok((listing_id, duration))
}

fn parse_donation_ref(external_ref: &str) -> Result<Option<Uuid>, AppError> {
    let separator = if external_ref.contains(':') { ':' } else { '_' };
    let parts: Vec<&str> = external_ref.split(separator).collect();
    if parts.len() < 2 {
        return Err(AppError::BadRequest("Malformed external_reference for donation".to_string()));
    }
    let user_id_str = parts[1];
    if user_id_str == "anonymous" {
        Ok(None)
    } else {
        let uid = Uuid::parse_str(user_id_str)
            .map_err(|_| AppError::BadRequest("Invalid user_id UUID".to_string()))?;
        Ok(Some(uid))
    }
}

/// Keeps a durable record of money Fapshi collected that was not credited to
/// anything, so it can be refunded by hand. An error here fails the webhook,
/// which makes Fapshi retry rather than lose the record.
pub(crate) async fn record_unmatched_payment<'e, E>(
    executor: E,
    reference: &str,
    amount: f64,
    external_ref: &str,
    reason: &str,
) -> Result<(), AppError>
where
    E: sqlx::PgExecutor<'e>,
{
    tracing::warn!("Unmatched Fapshi payment {}: {}", reference, reason);
    sqlx::query(
        "INSERT INTO fapshi_audit_logs (transaction_id, endpoint, request_payload, response_payload, status_code) \
         VALUES (NULL, 'webhook/unmatched-payment', $1, NULL, NULL)",
    )
    .bind(serde_json::json!({
        "transId": reference,
        "amount": amount,
        "externalId": external_ref,
        "reason": reason,
    }))
    .execute(executor)
    .await?;
    Ok(())
}

pub(crate) const ALREADY_SOLD_REASON: &str = "listing already sold to another buyer";

/// A buyer paid for a listing someone else bought first. Inside the caller's
/// DB transaction, marks their claimed transaction failed and records the
/// money as unmatched so an admin refunds it. Doing both atomically means a
/// retried webhook neither loses nor duplicates the refund record.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn fail_purchase_as_unmatched(
    conn: &mut sqlx::PgConnection,
    tx_id: Uuid,
    listing_id: Uuid,
    buyer_id: Uuid,
    reference: &str,
    amount: f64,
    external_ref: &str,
) -> Result<(), AppError> {
    sqlx::query("UPDATE transactions SET status = 'failed' WHERE id = $1")
        .bind(tx_id)
        .execute(&mut *conn)
        .await?;
    crate::routes::payments::release_reservation(&mut *conn, listing_id, buyer_id).await?;
    record_unmatched_payment(&mut *conn, reference, amount, external_ref, ALREADY_SOLD_REASON)
        .await
}

async fn handle_boost_success(
    pool: &PgPool,
    reference: &str,
    amount: f64,
    external_ref: &str,
) -> Result<(), AppError> {
    let (listing_id, requested_days) = parse_boost_ref(external_ref)?;
    // The price and duration are fixed server-side; the externalId's duration
    // is ignored so a payment can't buy a longer boost than it paid for.
    if !covers_expected(amount, BOOST_PRICE_XAF as f64) {
        let reason = format!("boost underpaid: costs {BOOST_PRICE_XAF} XAF");
        return record_unmatched_payment(pool, reference, amount, external_ref, &reason).await;
    }
    if requested_days != BOOST_DAYS {
        tracing::warn!(
            "Boost payment {} asked for {} days; granting {}",
            reference, requested_days, BOOST_DAYS
        );
    }
    let duration = BOOST_DAYS;

    let listing_row = sqlx::query("SELECT seller_id FROM listings WHERE id = $1")
        .bind(listing_id)
        .fetch_optional(pool)
        .await?;

    let listing = match listing_row {
        Some(row) => row,
        None => return Err(AppError::BadRequest(format!("Listing {} not found for boost", listing_id))),
    };
    let user_id: Uuid = listing.get("seller_id");

    let now = Utc::now();
    let rows_affected = sqlx::query(
        "INSERT INTO boost_payments ( \
            payment_reference, listing_id, user_id, amount, duration_days, status, created_at \
         ) \
         VALUES ($1, $2, $3, $4, $5, 'successful', $6) \
         ON CONFLICT (payment_reference) DO NOTHING"
    )
    .bind(reference)
    .bind(listing_id)
    .bind(user_id)
    .bind(amount)
    .bind(duration)
    .bind(now)
    .execute(pool)
    .await?
    .rows_affected();

    if rows_affected == 0 {
        tracing::info!("Boost payment with reference {} already recorded. Skipping listing boost update.", reference);
        return Ok(());
    }

    let expires_at = now + chrono::Duration::days(duration as i64);
    sqlx::query(
        "UPDATE listings SET is_boosted = true, boost_expires_at = $1 WHERE id = $2"
    )
    .bind(expires_at)
    .bind(listing_id)
    .execute(pool)
    .await?;

    Ok(())
}

/// Grants (or extends) Power Seller for one paid period. Renewals stack on
/// the latest active expiry so paying early never loses days. Idempotent on
/// the Fapshi transId.
pub(crate) async fn handle_subscription_success(
    pool: &PgPool,
    reference: &str,
    amount: f64,
    external_ref: &str,
) -> Result<(), AppError> {
    let user_id = match parse_external_ref(external_ref) {
        Some(ExternalRef::Subscription { user_id }) => user_id,
        _ => {
            return Err(AppError::BadRequest(format!(
                "Invalid subscription externalId: {external_ref}"
            )))
        }
    };
    if !covers_expected(amount, SUBSCRIPTION_PRICE_XAF as f64) {
        let reason = format!("subscription underpaid: costs {SUBSCRIPTION_PRICE_XAF} XAF");
        return record_unmatched_payment(pool, reference, amount, external_ref, &reason).await;
    }

    let mut tx = pool.begin().await?;
    let profile = sqlx::query("SELECT id FROM profiles WHERE id = $1 FOR UPDATE")
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await?;
    if profile.is_none() {
        record_unmatched_payment(
            &mut *tx,
            reference,
            amount,
            external_ref,
            "subscription for unknown profile",
        )
        .await?;
        tx.commit().await?;
        return Ok(());
    }

    let inserted = sqlx::query(
        "INSERT INTO subscriptions
             (user_id, tier, status, fapshi_reference, amount, started_at, expires_at)
         SELECT $1, 'power_seller', 'active', $2, $3, now(),
                greatest(now(), coalesce(max(s.expires_at), now())) + make_interval(days => $4)
         FROM (SELECT expires_at FROM subscriptions
               WHERE user_id = $1 AND status = 'active' AND expires_at > now()) s
         ON CONFLICT (fapshi_reference) DO NOTHING
         RETURNING id",
    )
    .bind(user_id)
    .bind(reference)
    .bind(amount.round() as i32)
    .bind(SUBSCRIPTION_DAYS)
    .fetch_optional(&mut *tx)
    .await?;

    if inserted.is_none() {
        tracing::info!(
            "Subscription payment {} already recorded; skipping",
            reference
        );
        tx.commit().await?;
        return Ok(());
    }

    sqlx::query("UPDATE profiles SET tier = 'power_seller' WHERE id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    tracing::info!(%user_id, "Power Seller granted via payment {}", reference);
    Ok(())
}

async fn handle_donation_success(
    pool: &PgPool,
    reference: &str,
    amount: f64,
    external_ref: &str,
) -> Result<(), AppError> {
    let user_id = parse_donation_ref(external_ref)?;
    let now = Utc::now();

    sqlx::query(
        "INSERT INTO donations (payment_reference, user_id, amount, status, created_at) \
         VALUES ($1, $2, $3, 'successful', $4) \
         ON CONFLICT (payment_reference) DO NOTHING"
    )
    .bind(reference)
    .bind(user_id)
    .bind(amount)
    .bind(now)
    .execute(pool)
    .await?;

    Ok(())
}

async fn handle_purchase_success(
    state: &AppState,
    reference: &str,
    amount: f64,
    external_ref: &str,
) -> Result<(), AppError> {
    let (listing_id, buyer_id) = parse_purchase_ref(external_ref)?;

    let listing_row = sqlx::query(
        "SELECT seller_id, price_fcfa::bigint AS price, status FROM listings WHERE id = $1",
    )
    .bind(listing_id)
    .fetch_optional(&state.pool)
    .await?;

    let listing = match listing_row {
        Some(row) => row,
        None => return Err(AppError::BadRequest(format!("Listing {} not found for purchase", listing_id))),
    };
    let seller_id: Uuid = listing.get("seller_id");
    let listing_price: Option<i64> = listing.try_get("price")?;
    let listing_status: Option<String> = listing.try_get("status")?;

    // The amount a purchase must cover: the server-set price plus buyer fee
    // recorded when the payment was initiated, or the listing's current
    // price plus fee if there is no such row (the pending insert failed).
    let existing = sqlx::query(
        "SELECT amount::bigint AS price, buyer_fee::bigint AS buyer_fee, listing_id, buyer_id \
         FROM transactions WHERE payment_reference = $1",
    )
    .bind(reference)
    .fetch_optional(&state.pool)
    .await?;

    let (price, buyer_fee) = match existing {
        Some(row) => {
            let row_listing: Uuid = row.try_get("listing_id")?;
            let row_buyer: Uuid = row.try_get("buyer_id")?;
            if row_listing != listing_id || row_buyer != buyer_id {
                return record_unmatched_payment(
                    &state.pool,
                    reference,
                    amount,
                    external_ref,
                    "externalId does not match the recorded transaction",
                )
                .await;
            }
            let price: i64 = row.try_get("price")?;
            let buyer_fee: i64 = row.try_get("buyer_fee")?;
            (price, buyer_fee)
        }
        None => {
            if buyer_id == seller_id || listing_status.as_deref() != Some("available") {
                return record_unmatched_payment(
                    &state.pool,
                    reference,
                    amount,
                    external_ref,
                    "no recorded purchase, and the listing is not available to this buyer",
                )
                .await;
            }
            match listing_price {
                Some(price) => (price, buyer_fee_for(price)),
                None => {
                    return record_unmatched_payment(
                        &state.pool,
                        reference,
                        amount,
                        external_ref,
                        "no recorded purchase, and the listing has no price",
                    )
                    .await;
                }
            }
        }
    };

    let expected = (price + buyer_fee) as f64;
    if !covers_expected(amount, expected) {
        let reason = format!("purchase underpaid: expected {expected} XAF");
        return record_unmatched_payment(&state.pool, reference, amount, external_ref, &reason)
            .await;
    }

    let now = Utc::now();
    // The claim and the escrow writes share one DB transaction, so a failed
    // escrow write leaves the row claimable by Fapshi's retry or the poller.
    let mut transaction = state.pool.begin().await?;

    // Atomically upsert the transaction using ON CONFLICT DO UPDATE.
    // If the transaction status is already 'held' or 'successful' (completed), the DO UPDATE will fail the WHERE clause
    // and return 0 rows.
    let tx_row = sqlx::query(
        "INSERT INTO transactions ( \
            payment_reference, listing_id, buyer_id, seller_id, amount, buyer_fee, status, \
            payout_status, payout_reference, commission_amount, created_at \
         ) \
         VALUES ($1, $2, $3, $4, $5, $6, 'held', 'pending', NULL, 0, $7) \
         ON CONFLICT (payment_reference) \
         DO UPDATE SET \
             status = 'held' \
         WHERE transactions.status = 'pending_payment' \
         RETURNING id"
    )
    .bind(reference)
    .bind(listing_id)
    .bind(buyer_id)
    .bind(seller_id)
    .bind(price as i32)
    .bind(buyer_fee as i32)
    .bind(now)
    .fetch_optional(&mut *transaction)
    .await?;

    let tx_id = match tx_row {
        Some(row) => {
            let id: Uuid = row.get("id");
            id
        }
        None => {
            tracing::info!("Transaction with reference {} already claimed or processed. Skipping success logic.", reference);
            transaction.rollback().await?;
            return Ok(());
        }
    };

    match handle_purchase_success_db(
        &mut transaction,
        listing_id,
        buyer_id,
        seller_id,
        tx_id,
        now,
    ).await {
        Ok(PurchaseOutcome::Held) => {}
        Ok(PurchaseOutcome::AlreadySold) => {
            tracing::error!(
                "Purchase {} paid for listing {} which is already sold; recording for refund",
                reference, listing_id
            );
            if let Err(e) = fail_purchase_as_unmatched(
                &mut transaction, tx_id, listing_id, buyer_id, reference, amount, external_ref,
            ).await {
                transaction.rollback().await?;
                return Err(e);
            }
        }
        Err(e) => {
            tracing::error!("Error writing webhook purchase success updates: {:?}", e);
            transaction.rollback().await?;
            return Err(e);
        }
    }

    transaction.commit().await?;

    Ok(())
}

/// Pending purchases are recorded by `/payments/initiate` with the
/// server-set price. A webhook must never create one, because its amount and
/// externalId would come from whoever initiated the payment.
fn handle_purchase_pending(reference: &str, external_ref: &str) -> Result<(), AppError> {
    parse_purchase_ref(external_ref)?;
    tracing::info!("Purchase {} is pending at Fapshi", reference);
    Ok(())
}

pub async fn fapshi_webhook_handler(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<serde_json::Value>,
) -> Result<impl IntoResponse, AppError> {
    verify_webhook_auth(&state.pool, &headers).await?;

    let payload_val = if let Some(arr) = body.as_array() {
        if arr.is_empty() {
            return Err(AppError::BadRequest("Empty payload array".to_string()));
        }
        &arr[0]
    } else if body.is_object() {
        &body
    } else {
        return Err(AppError::BadRequest("Invalid webhook payload format".to_string()));
    };

    let payload: FapshiWebhookPayload = serde_json::from_value(payload_val.clone())
        .map_err(|e| AppError::BadRequest(format!("Failed to parse webhook payload: {}", e)))?;

    let status = payload.status.or(payload.state).ok_or_else(|| AppError::BadRequest("Missing status/state field".to_string()))?;
    let reference = payload.trans_id.or(payload.transaction_id).or(payload.id).ok_or_else(|| AppError::BadRequest("Missing transId/id reference field".to_string()))?;
    let amount_val = payload.amount.ok_or_else(|| AppError::BadRequest("Missing amount field".to_string()))?;
    let external_reference = payload.external_id.or(payload.external_reference).or(payload.custom).unwrap_or_default();

    let amount = match amount_val {
        serde_json::Value::Number(num) => num.as_f64().unwrap_or(0.0),
        serde_json::Value::String(s) => s.parse::<f64>().unwrap_or(0.0),
        _ => return Err(AppError::BadRequest("Invalid amount type".to_string())),
    };

    let status_upper = status.to_uppercase();

    tracing::info!("Processing incoming Fapshi webhook for ref: {}, status: {}, external: {}", reference, status_upper, external_reference);

    if status_upper == "SUCCESSFUL" || status_upper == "SUCCESS" {
        if external_reference.starts_with("boost:") || external_reference.starts_with("boost_") {
            handle_boost_success(&state.pool, &reference, amount, &external_reference).await?;
        } else if external_reference.starts_with("subscription:")
            || external_reference.starts_with("subscription_")
        {
            handle_subscription_success(&state.pool, &reference, amount, &external_reference)
                .await?;
        } else if external_reference.starts_with("donation:") || external_reference.starts_with("donation_") {
            handle_donation_success(&state.pool, &reference, amount, &external_reference).await?;
        } else if external_reference.starts_with("purchase:") || external_reference.starts_with("purchase_") {
            handle_purchase_success(&state, &reference, amount, &external_reference).await?;
        } else {
            tracing::warn!("Unknown externalReference: {}", external_reference);
        }
    } else if (status_upper == "CREATED" || status_upper == "PENDING" || status_upper == "PENDING_PAYMENT")
        && (external_reference.starts_with("purchase:") || external_reference.starts_with("purchase_"))
    {
        handle_purchase_pending(&reference, &external_reference)?;
    } else if (status_upper == "FAILED" || status_upper == "EXPIRED")
        && (external_reference.starts_with("purchase:") || external_reference.starts_with("purchase_"))
    {
        tracing::info!("Marking transaction failed: Ref={}", reference);
        let failed = sqlx::query(
            "UPDATE transactions SET status = 'failed' \
             WHERE payment_reference = $1 AND status = 'pending_payment' \
             RETURNING listing_id, buyer_id",
        )
        .bind(&reference)
        .fetch_optional(&state.pool)
        .await?;
        if let Some(row) = failed {
            let listing_id: Uuid = row.try_get("listing_id")?;
            let buyer_id: Uuid = row.try_get("buyer_id")?;
            crate::routes::payments::release_reservation(&state.pool, listing_id, buyer_id).await?;
        }
    }

    Ok((axum::http::StatusCode::OK, Json(serde_json::json!({ "success": true }))))
}
