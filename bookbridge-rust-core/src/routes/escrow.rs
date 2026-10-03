use axum::{extract::State, Json, response::IntoResponse};
use serde::Serialize;
use crate::error::AppError;
use crate::fapshi::FapshiClient;
use crate::routes::payments::{seller_payout, MIN_AMOUNT_XAF};
use crate::AppState;
use sqlx::Row;
use sqlx::PgConnection;
use uuid::Uuid;
use chrono::Utc;

#[derive(Serialize)]
pub struct ProcessReleasesResponse {
    pub processed: usize,
    pub released: usize,
    pub failed: usize,
    pub results: Vec<ReleaseResult>,
}

#[derive(Serialize)]
pub struct ReleaseResult {
    pub transaction_id: Uuid,
    pub ok: bool,
    pub error: Option<String>,
}

#[derive(Serialize)]
pub struct PollPendingResponse {
    pub processed: usize,
    pub results: Vec<PollResult>,
}

#[derive(Serialize)]
pub struct PollResult {
    pub id: Uuid,
    pub reference: String,
    pub status: String,
    pub error: Option<String>,
}

/// Whether a successful payment got the book.
#[derive(Debug, PartialEq, Eq)]
pub enum PurchaseOutcome {
    /// The listing was marked sold and the money is held in escrow.
    Held,
    /// Another buyer already bought the listing. Nothing was written; the
    /// caller must roll back and refund this buyer.
    AlreadySold,
}

/// Shared helper function to process all database side effects for a successful book purchase.
/// This includes marking the listing as sold, setting the transaction to 'held', upserting the escrow row,
/// and creating the initial buyer/seller chat message.
pub async fn handle_purchase_success_db(
    conn: &mut PgConnection,
    listing_id: Uuid,
    buyer_id: Uuid,
    seller_id: Uuid,
    tx_id: Uuid,
    now: chrono::DateTime<chrono::Utc>,
) -> Result<PurchaseOutcome, AppError> {
    // 1. Mark the listing sold. The row lock makes this the single point where
    // two concurrent successful payments are ordered; only the first wins.
    let marked = sqlx::query(
        "UPDATE listings SET status = 'sold' \
         WHERE id = $1 AND status IS DISTINCT FROM 'sold' RETURNING id",
    )
    .bind(listing_id)
    .fetch_optional(&mut *conn)
    .await?;
    if marked.is_none() {
        return Ok(PurchaseOutcome::AlreadySold);
    }

    sqlx::query("DELETE FROM listing_reservations WHERE listing_id = $1")
        .bind(listing_id)
        .execute(&mut *conn)
        .await?;

    // 2. Update transaction status to 'held'
    sqlx::query("UPDATE transactions SET status = 'held' WHERE id = $1")
        .bind(tx_id)
        .execute(&mut *conn)
        .await?;

    // 3. Upsert escrow transaction atomically
    sqlx::query(
        "INSERT INTO escrow_transactions (transaction_id, status, created_at, updated_at) \
         VALUES ($1, 'held', $2, $2) \
         ON CONFLICT (transaction_id) DO UPDATE SET status = 'held', updated_at = $2"
    )
    .bind(tx_id)
    .bind(now)
    .execute(&mut *conn)
    .await?;

    // 4. Insert automated buyer/seller chat message
    sqlx::query(
        "INSERT INTO messages (listing_id, sender_id, receiver_id, content, is_read, created_at) \
         VALUES ($1, $2, $3, $4, false, $5)"
    )
    .bind(listing_id)
    .bind(buyer_id)
    .bind(seller_id)
    .bind("Hello! I just purchased this book via BookBridge. When can we meet to complete the exchange?")
    .bind(now)
    .execute(&mut *conn)
    .await?;

    Ok(PurchaseOutcome::Held)
}

/// Marks a transaction as busy (payout or dispute) in this process; released on drop.
/// The lock is per process, so it assumes a single service instance.
pub(crate) struct InProgressGuard {
    tx_id: Uuid,
    in_progress: std::sync::Arc<std::sync::Mutex<std::collections::HashSet<Uuid>>>,
}

impl InProgressGuard {
    pub(crate) fn claim(state: &AppState, tx_id: Uuid) -> Result<Self, AppError> {
        let mut in_progress = state.in_progress_payouts.lock().map_err(|_| {
            AppError::Internal("Failed to acquire in-progress lock".to_string())
        })?;
        if !in_progress.insert(tx_id) {
            return Err(AppError::BadRequest(format!("Payout for transaction {} is already in progress", tx_id)));
        }
        Ok(Self {
            tx_id,
            in_progress: state.in_progress_payouts.clone(),
        })
    }
}

impl Drop for InProgressGuard {
    fn drop(&mut self) {
        if let Ok(mut lock) = self.in_progress.lock() {
            lock.remove(&self.tx_id);
        }
    }
}

/// An admin's decision, recorded in `admin_actions` in the same database
/// transaction as the status change it causes.
pub(crate) struct AdminDecision<'a> {
    pub admin_id: Uuid,
    pub action: &'a str,
    pub note: &'a str,
}

pub(crate) async fn record_admin_action(
    conn: &mut PgConnection,
    decision: &AdminDecision<'_>,
    transaction_id: Option<Uuid>,
    audit_log_id: Option<Uuid>,
    payout_reference: Option<&str>,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO admin_actions (admin_id, action, transaction_id, audit_log_id, payout_reference, note) \
         VALUES ($1, $2, $3, $4, $5, $6)",
    )
    .bind(decision.admin_id)
    .bind(decision.action)
    .bind(transaction_id)
    .bind(audit_log_id)
    .bind(payout_reference)
    .bind(decision.note)
    .execute(&mut *conn)
    .await?;
    Ok(())
}

/// Pays the seller for a `held` escrow (buyer confirmation or deadline).
pub async fn release_escrow(
    state: &AppState,
    tx_id: Uuid,
) -> Result<(), AppError> {
    // 1. Claim in-progress lock to mitigate concurrent execution / double payout risk
    let _guard = InProgressGuard::claim(state, tx_id)?;
    release_escrow_locked(state, tx_id, "held", None).await
}

/// Pays the seller for an escrow whose transaction and escrow rows are both
/// `from_status`. The caller must hold the transaction's `InProgressGuard`.
pub(crate) async fn release_escrow_locked(
    state: &AppState,
    tx_id: Uuid,
    from_status: &str,
    admin: Option<&AdminDecision<'_>>,
) -> Result<(), AppError> {
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());

    // 2. Fetch transaction and escrow status to ensure both are in `from_status`
    let tx_row = sqlx::query(
        "SELECT t.listing_id, t.seller_id, t.amount::float8 AS amount, \
         t.commission_amount::float8 AS commission_amount, t.payment_reference, \
         t.status as tx_status, e.status as escrow_status \
         FROM transactions t \
         JOIN escrow_transactions e ON t.id = e.transaction_id \
         WHERE t.id = $1"
    )
    .bind(tx_id)
    .fetch_optional(&state.pool)
    .await?;

    let tx = match tx_row {
        Some(row) => {
            let tx_status: String = row.get("tx_status");
            let escrow_status: String = row.get("escrow_status");
            if tx_status != from_status || escrow_status != from_status {
                return Err(AppError::BadRequest(format!(
                    "Transaction or Escrow {} is not in '{}' status (tx: {}, escrow: {})",
                    tx_id, from_status, tx_status, escrow_status
                )));
            }
            row
        }
        None => return Err(AppError::BadRequest(format!("Transaction {} not found", tx_id))),
    };

    let listing_id: Uuid = tx.get("listing_id");
    let seller_id: Uuid = tx.get("seller_id");
    let amount: f64 = tx.get("amount");
    let commission_amount: Option<f64> = tx.get("commission_amount");
    let payment_reference: String = tx.get("payment_reference");

    // 3. Fetch seller profile; the payout number lives in owner-only profiles_private
    let seller_row = sqlx::query(
        "SELECT ppr.whatsapp_number, pr.full_name \
         FROM profiles pr \
         LEFT JOIN profiles_private ppr ON ppr.id = pr.id \
         WHERE pr.id = $1"
    )
    .bind(seller_id)
    .fetch_optional(&state.pool)
    .await?;

    let seller = match seller_row {
        Some(row) => row,
        None => return Err(AppError::BadRequest(format!("Seller profile {} not found", seller_id))),
    };

    let whatsapp_number: Option<String> = seller.get("whatsapp_number");
    let full_name: Option<String> = seller.get("full_name");

    let phone = match whatsapp_number {
        Some(num) if !num.trim().is_empty() => num,
        _ => return Err(AppError::BadRequest("Seller has no payout number configured".to_string())),
    };

    let payout_amount = seller_payout(amount, commission_amount.unwrap_or(0.0)).ok_or_else(|| {
        AppError::BadRequest(format!(
            "Transaction {} is below Fapshi's {} XAF payout minimum",
            tx_id, MIN_AMOUNT_XAF
        ))
    })?;
    let external_id = format!("escrow_payout_{}", payment_reference);
    let seller_name_str = full_name.unwrap_or_else(|| "BookBridge Seller".to_string());

    // Check if payout was already executed successfully on Fapshi in a previous run
    let mut trans_id = match fapshi.check_existing_payout(&state.pool, &external_id).await {
        Ok(Some(tid)) => {
            tracing::info!("Payout for transaction {} already completed on Fapshi (transId: {}). Skipping payout call.", tx_id, tid);
            Some(tid)
        }
        Ok(None) => None, // Safe to proceed with payout
        Err(e) => {
            tracing::error!("Could not verify prior payout status for tx {}: {:?}. Aborting to prevent potential double-payout.", tx_id, e);
            return Err(e); // Fail closed - let the next cron run retry
        }
    };

    // If not already processed, execute payout
    if trans_id.is_none() {
        let tid = fapshi.execute_payout(
            &state.pool,
            Some(tx_id),
            payout_amount,
            &phone,
            &seller_name_str,
            &external_id,
            &format!("BookBridge escrow payout for listing {}", listing_id),
        )
        .await?;
        trans_id = Some(tid);
    }

    let trans_id_str = trans_id.unwrap_or_default();

    // 5. Update databases only after payout is verified successful
    let now = Utc::now();
    let mut transaction = state.pool.begin().await?;

    sqlx::query(
        "UPDATE escrow_transactions SET status = 'released', updated_at = $1 \
         WHERE transaction_id = $2 AND status = $3"
    )
    .bind(now)
    .bind(tx_id)
    .bind(from_status)
    .execute(&mut *transaction)
    .await?;

    sqlx::query(
        "UPDATE transactions SET status = 'successful', payout_status = 'successful', payout_reference = $1, \
         commission_amount = $3 \
         WHERE id = $2"
    )
    .bind(&trans_id_str)
    .bind(tx_id)
    .bind(amount - payout_amount)
    .execute(&mut *transaction)
    .await?;

    if let Some(decision) = admin {
        record_admin_action(&mut transaction, decision, Some(tx_id), None, Some(&trans_id_str)).await?;
    }

    transaction.commit().await?;

    Ok(())
}

pub async fn process_releases_handler(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    let now = Utc::now();

    // Find all held escrows whose release_deadline has passed
    let expired_rows = sqlx::query(
        "SELECT transaction_id FROM escrow_transactions \
         WHERE status = 'held' AND release_deadline <= $1"
    )
    .bind(now)
    .fetch_all(&state.pool)
    .await?;

    let mut results = Vec::new();
    let mut released_count = 0;
    let mut failed_count = 0;

    for row in expired_rows {
        let tx_id: Uuid = row.get("transaction_id");
        match release_escrow(&state, tx_id).await {
            Ok(_) => {
                released_count += 1;
                results.push(ReleaseResult {
                    transaction_id: tx_id,
                    ok: true,
                    error: None,
                });
            }
            Err(e) => {
                failed_count += 1;
                let err_str = e.to_string();
                tracing::error!("Failed to auto-release escrow {}: {}", tx_id, err_str);
                results.push(ReleaseResult {
                    transaction_id: tx_id,
                    ok: false,
                    error: Some(err_str),
                });
            }
        }
    }

    Ok(Json(ProcessReleasesResponse {
        processed: results.len(),
        released: released_count,
        failed: failed_count,
        results,
    }))
}

pub async fn poll_pending_handler(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());

    // Find all transactions stuck in pending_payment for more than 10 minutes
    let ten_minutes_ago = Utc::now() - chrono::Duration::minutes(10);
    
    let txs = sqlx::query(
        "SELECT id, payment_reference, listing_id, buyer_id, seller_id, amount::float8 AS amount \
         FROM transactions \
         WHERE status = 'pending_payment' AND created_at <= $1"
    )
    .bind(ten_minutes_ago)
    .fetch_all(&state.pool)
    .await?;

    let mut results = Vec::new();

    for row in txs {
        let tx_id: Uuid = row.get("id");
        let reference: String = row.get("payment_reference");
        let listing_id: Uuid = row.get("listing_id");
        let buyer_id: Uuid = row.get("buyer_id");
        let seller_id: Uuid = row.get("seller_id");
        let amount: f64 = row.try_get::<Option<f64>, _>("amount")?.unwrap_or(0.0);

        tracing::info!("Checking Fapshi status for transaction ref: {}", reference);

        match fapshi.poll_payment_status(&state.pool, tx_id, &reference).await {
            Ok(fapshi_status) => {
                let status_upper = fapshi_status.to_uppercase();
                if status_upper == "SUCCESSFUL" || status_upper == "SUCCESS" {
                    // Process successful payment
                    let now = Utc::now();
                    let mut transaction = state.pool.begin().await?;

                    // Claim the row so a webhook that settled it meanwhile
                    // (or an overlapping poll) isn't processed twice.
                    let claimed = sqlx::query(
                        "UPDATE transactions SET status = 'held' \
                         WHERE id = $1 AND status = 'pending_payment' RETURNING id",
                    )
                    .bind(tx_id)
                    .fetch_optional(&mut *transaction)
                    .await?;
                    if claimed.is_none() {
                        transaction.rollback().await?;
                        results.push(PollResult {
                            id: tx_id,
                            reference: reference.clone(),
                            status: "already_settled".to_string(),
                            error: None,
                        });
                        continue;
                    }

                    let outcome = handle_purchase_success_db(
                        &mut transaction,
                        listing_id,
                        buyer_id,
                        seller_id,
                        tx_id,
                        now,
                    ).await;
                    let outcome = match outcome {
                        Ok(PurchaseOutcome::AlreadySold) => {
                            // The poller doesn't see Fapshi's externalId; this
                            // identifies the same listing and buyer for the admin.
                            let external_ref = format!("purchase_{listing_id}_{buyer_id}");
                            crate::routes::webhook::fail_purchase_as_unmatched(
                                &mut transaction, tx_id, listing_id, buyer_id, &reference, amount, &external_ref,
                            )
                            .await
                            .map(|_| PurchaseOutcome::AlreadySold)
                        }
                        other => other,
                    };
                    let outcome = match outcome {
                        Ok(outcome) => outcome,
                        Err(e) => {
                            tracing::error!("Error writing successful purchase updates to DB during poll: {:?}", e);
                            transaction.rollback().await?;
                            results.push(PollResult {
                                id: tx_id,
                                reference: reference.clone(),
                                status: "error".to_string(),
                                error: Some(e.to_string()),
                            });
                            continue;
                        }
                    };

                    transaction.commit().await?;

                    let status = match outcome {
                        PurchaseOutcome::Held => "held",
                        PurchaseOutcome::AlreadySold => "already_sold",
                    };
                    results.push(PollResult {
                        id: tx_id,
                        reference: reference.clone(),
                        status: status.to_string(),
                        error: None,
                    });
                } else if status_upper == "FAILED" || status_upper == "EXPIRED" {
                    // Mark transaction as failed
                    let failed = sqlx::query("UPDATE transactions SET status = 'failed' WHERE id = $1 AND status = 'pending_payment'")
                        .bind(tx_id)
                        .execute(&state.pool)
                        .await?;
                    if failed.rows_affected() > 0 {
                        crate::routes::payments::release_reservation(&state.pool, listing_id, buyer_id).await?;
                    }

                    results.push(PollResult {
                        id: tx_id,
                        reference: reference.clone(),
                        status: "failed".to_string(),
                        error: None,
                    });
                } else {
                    // Still pending/created
                    results.push(PollResult {
                        id: tx_id,
                        reference: reference.clone(),
                        status: fapshi_status.clone(),
                        error: None,
                    });
                }
            }
            Err(e) => {
                let err_str = e.to_string();
                tracing::error!("Error polling transaction status for {}: {}", reference, err_str);
                results.push(PollResult {
                    id: tx_id,
                    reference: reference.clone(),
                    status: "error".to_string(),
                    error: Some(err_str),
                });
            }
        }
    }

    Ok(Json(PollPendingResponse {
        processed: results.len(),
        results,
    }))
}
