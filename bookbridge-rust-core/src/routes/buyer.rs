//! Buyer-facing escrow actions: confirm receipt (releases the payout) and
//! open a dispute. These replace the `release` and `dispute` actions of the
//! `process-escrow` edge function, reusing `release_escrow`, which requires
//! both the transaction and the escrow row to be `held` and checks Fapshi
//! for an existing payout before paying.

use axum::{extract::State, routing::post, Json, Router};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::error::AppError;
use crate::routes::escrow::{release_escrow, InProgressGuard};
use crate::user_auth::AuthenticatedUser;
use crate::AppState;

pub const MAX_DISPUTE_REASON_CHARS: usize = 1000;

#[derive(Deserialize)]
pub struct ConfirmReceiptRequest {
    pub transaction_id: Uuid,
}

#[derive(Deserialize)]
pub struct DisputeRequest {
    pub transaction_id: Uuid,
    pub dispute_reason: String,
}

#[derive(Serialize)]
pub struct OkResponse {
    pub ok: bool,
}

pub fn buyer_routes() -> Router<AppState> {
    Router::new()
        .route("/escrow/confirm-receipt", post(confirm_receipt_handler))
        .route("/escrow/dispute", post(dispute_handler))
}

// `AuthenticatedUser` comes before `Json`, so unauthenticated requests are
// rejected before the body is read.
pub async fn confirm_receipt_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
    Json(request): Json<ConfirmReceiptRequest>,
) -> Result<Json<OkResponse>, AppError> {
    confirm_receipt(&state, user_id, request.transaction_id).await?;
    Ok(Json(OkResponse { ok: true }))
}

pub async fn dispute_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
    Json(request): Json<DisputeRequest>,
) -> Result<Json<OkResponse>, AppError> {
    dispute_escrow(
        &state,
        user_id,
        request.transaction_id,
        &request.dispute_reason,
    )
    .await?;
    Ok(Json(OkResponse { ok: true }))
}

pub async fn confirm_receipt(
    state: &AppState,
    buyer_id: Uuid,
    tx_id: Uuid,
) -> Result<(), AppError> {
    ensure_buyer_of_held(state, buyer_id, tx_id).await?;
    release_escrow(state, tx_id).await
}

pub async fn dispute_escrow(
    state: &AppState,
    buyer_id: Uuid,
    tx_id: Uuid,
    raw_reason: &str,
) -> Result<(), AppError> {
    let reason = validate_dispute_reason(raw_reason)?;

    // Blocks a dispute from landing while a payout for this transaction is running.
    let _guard = match InProgressGuard::claim(state, tx_id) {
        Err(AppError::BadRequest(_)) => {
            return Err(AppError::Conflict(
                "A payout for this transaction is in progress".to_string(),
            ))
        }
        other => other?,
    };

    ensure_buyer_of_held(state, buyer_id, tx_id).await?;

    let now = Utc::now();
    let mut db = state.pool.begin().await?;

    let escrow = sqlx::query(
        "UPDATE escrow_transactions SET status = 'disputed', dispute_reason = $2, updated_at = $3 \
         WHERE transaction_id = $1 AND status = 'held'",
    )
    .bind(tx_id)
    .bind(&reason)
    .bind(now)
    .execute(&mut *db)
    .await?;

    let tx = sqlx::query(
        "UPDATE transactions SET status = 'disputed' \
         WHERE id = $1 AND buyer_id = $2 AND status = 'held'",
    )
    .bind(tx_id)
    .bind(buyer_id)
    .execute(&mut *db)
    .await?;

    if escrow.rows_affected() != 1 || tx.rows_affected() != 1 {
        db.rollback().await?;
        return Err(AppError::Conflict(format!(
            "Transaction {tx_id} has no held escrow to dispute"
        )));
    }

    db.commit().await?;
    Ok(())
}

pub fn validate_dispute_reason(raw: &str) -> Result<String, AppError> {
    let reason = raw.trim();
    if reason.is_empty() {
        return Err(AppError::BadRequest(
            "dispute_reason is required".to_string(),
        ));
    }
    if reason.chars().count() > MAX_DISPUTE_REASON_CHARS {
        return Err(AppError::BadRequest(format!(
            "dispute_reason must be at most {MAX_DISPUTE_REASON_CHARS} characters"
        )));
    }
    Ok(reason.to_string())
}

/// Other users' transactions get the same 404 as missing ones, so the
/// endpoint doesn't reveal which transaction ids exist.
async fn ensure_buyer_of_held(
    state: &AppState,
    buyer_id: Uuid,
    tx_id: Uuid,
) -> Result<(), AppError> {
    let not_found = || AppError::NotFound(format!("Transaction {tx_id} not found"));

    let row = sqlx::query("SELECT buyer_id, status FROM transactions WHERE id = $1")
        .bind(tx_id)
        .fetch_optional(&state.pool)
        .await?
        .ok_or_else(not_found)?;

    let owner: Option<Uuid> = row.try_get("buyer_id")?;
    if owner != Some(buyer_id) {
        return Err(not_found());
    }

    let status: Option<String> = row.try_get("status")?;
    match status.as_deref() {
        Some("held") => Ok(()),
        other => Err(AppError::Conflict(format!(
            "Transaction is '{}', not 'held'",
            other.unwrap_or("unknown")
        ))),
    }
}
