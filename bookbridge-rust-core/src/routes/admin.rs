//! Admin-only endpoints for money that needs a human decision: disputed
//! escrows (pay the seller or refund the buyer) and unmatched payments
//! (refund the payer or dismiss after handling it off-platform).
//!
//! Fapshi has no refund API, so a refund is a disbursement payout to the
//! number that paid. Every payout uses a deterministic externalId and checks
//! Fapshi for an earlier successful payout first, so a retry after a crash
//! never pays twice. Every decision is recorded in `admin_actions`.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::error::AppError;
use crate::fapshi::{FapshiClient, FapshiSearchItem};
use crate::routes::escrow::{
    record_admin_action, release_escrow_locked, AdminDecision, InProgressGuard,
};
use crate::routes::payments::{validate_phone, MIN_AMOUNT_XAF};
use crate::user_auth::AdminUser;
use crate::AppState;

pub const MAX_NOTE_CHARS: usize = 1000;
const LIST_LIMIT: i64 = 200;
const UNMATCHED_ENDPOINT: &str = "webhook/unmatched-payment";
/// Fapshi externalIds are limited to 100 characters.
const MAX_EXTERNAL_ID_CHARS: usize = 100;

#[derive(Deserialize)]
pub struct ResolveRequest {
    pub note: String,
    /// Refunds only: overrides the payer number recorded at checkout.
    pub phone: Option<String>,
}

#[derive(Serialize)]
pub struct AdminMeResponse {
    pub admin: bool,
}

#[derive(Serialize)]
pub struct ResolveResponse {
    pub ok: bool,
    pub payout_reference: Option<String>,
}

#[derive(Serialize)]
pub struct DisputeSummary {
    pub transaction_id: Uuid,
    pub amount: i64,
    pub listing_title: Option<String>,
    pub buyer_name: Option<String>,
    pub seller_name: Option<String>,
    pub dispute_reason: Option<String>,
    pub purchased_at: Option<DateTime<Utc>>,
    pub disputed_at: Option<DateTime<Utc>>,
    /// Masked number the buyer paid from, if recorded at checkout.
    pub payer_phone_hint: Option<String>,
}

#[derive(Serialize)]
pub struct DisputeList {
    pub disputes: Vec<DisputeSummary>,
}

#[derive(Serialize)]
pub struct UnmatchedPaymentList {
    pub payments: Vec<UnmatchedPayment>,
}

#[derive(Serialize)]
pub struct UnmatchedPayment {
    pub id: Uuid,
    pub trans_id: Option<String>,
    pub amount: Option<f64>,
    pub external_id: Option<String>,
    pub reason: Option<String>,
    pub received_at: Option<DateTime<Utc>>,
    pub payer_phone_hint: Option<String>,
}

pub fn admin_routes() -> Router<AppState> {
    Router::new()
        .route("/admin/me", get(me_handler))
        .route("/admin/disputes", get(list_disputes_handler))
        .route(
            "/admin/disputes/:tx_id/release",
            post(release_dispute_handler),
        )
        .route(
            "/admin/disputes/:tx_id/refund",
            post(refund_dispute_handler),
        )
        .route("/admin/unmatched-payments", get(list_unmatched_handler))
        .route(
            "/admin/unmatched-payments/:log_id/refund",
            post(refund_unmatched_handler),
        )
        .route(
            "/admin/unmatched-payments/:log_id/dismiss",
            post(dismiss_unmatched_handler),
        )
}

pub async fn me_handler(_admin: AdminUser) -> Json<AdminMeResponse> {
    Json(AdminMeResponse { admin: true })
}

pub async fn list_disputes_handler(
    State(state): State<AppState>,
    _admin: AdminUser,
) -> Result<Json<DisputeList>, AppError> {
    let rows = sqlx::query(
        "SELECT t.id, t.amount::bigint AS amount, t.created_at, e.dispute_reason, \
                e.updated_at AS disputed_at, l.title, b.full_name AS buyer_name, \
                s.full_name AS seller_name, pp.phone AS payer_phone \
         FROM transactions t \
         JOIN escrow_transactions e ON e.transaction_id = t.id \
         LEFT JOIN listings l ON l.id = t.listing_id \
         LEFT JOIN profiles b ON b.id = t.buyer_id \
         LEFT JOIN profiles s ON s.id = t.seller_id \
         LEFT JOIN payment_payers pp ON pp.payment_reference = t.payment_reference \
         WHERE t.status = 'disputed' AND e.status = 'disputed' \
         ORDER BY e.updated_at ASC NULLS FIRST \
         LIMIT $1",
    )
    .bind(LIST_LIMIT)
    .fetch_all(&state.pool)
    .await?;

    rows.into_iter()
        .map(|row| {
            Ok(DisputeSummary {
                transaction_id: row.try_get("id")?,
                amount: row.try_get("amount")?,
                listing_title: row.try_get("title")?,
                buyer_name: row.try_get("buyer_name")?,
                seller_name: row.try_get("seller_name")?,
                dispute_reason: row.try_get("dispute_reason")?,
                purchased_at: row.try_get("created_at")?,
                disputed_at: row.try_get("disputed_at")?,
                payer_phone_hint: row
                    .try_get::<Option<String>, _>("payer_phone")?
                    .as_deref()
                    .map(mask_phone),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()
        .map(|disputes| Json(DisputeList { disputes }))
}

pub async fn release_dispute_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(tx_id): Path<Uuid>,
    Json(request): Json<ResolveRequest>,
) -> Result<Json<ResolveResponse>, AppError> {
    let note = validate_note(&request.note)?;
    if request.phone.is_some() {
        return Err(AppError::BadRequest(
            "phone only applies to refunds; a release pays the seller's payout number".to_string(),
        ));
    }
    let _guard = claim(&state, tx_id)?;
    let decision = AdminDecision {
        admin_id,
        action: "release_dispute",
        note: &note,
    };
    release_escrow_locked(&state, tx_id, "disputed", Some(&decision)).await?;
    Ok(Json(ResolveResponse {
        ok: true,
        payout_reference: None,
    }))
}

pub async fn refund_dispute_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(tx_id): Path<Uuid>,
    Json(request): Json<ResolveRequest>,
) -> Result<Json<ResolveResponse>, AppError> {
    let note = validate_note(&request.note)?;
    let phone_override = request.phone.as_deref().map(validate_phone).transpose()?;
    let decision = AdminDecision {
        admin_id,
        action: "refund_dispute",
        note: &note,
    };
    let trans_id = refund_dispute(&state, tx_id, phone_override, &decision).await?;
    Ok(Json(ResolveResponse {
        ok: true,
        payout_reference: Some(trans_id),
    }))
}

/// Refunds the buyer the full amount paid and marks the purchase `refunded`.
/// The listing stays `sold`; relisting is the seller's call.
pub(crate) async fn refund_dispute(
    state: &AppState,
    tx_id: Uuid,
    phone_override: Option<String>,
    decision: &AdminDecision<'_>,
) -> Result<String, AppError> {
    let _guard = claim(state, tx_id)?;

    let row = sqlx::query(
        "SELECT t.listing_id, t.amount::bigint AS amount, t.payment_reference, \
                t.status AS tx_status, e.status AS escrow_status, pp.phone AS payer_phone \
         FROM transactions t \
         JOIN escrow_transactions e ON e.transaction_id = t.id \
         LEFT JOIN payment_payers pp ON pp.payment_reference = t.payment_reference \
         WHERE t.id = $1",
    )
    .bind(tx_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Transaction {tx_id} not found")))?;

    let tx_status: String = row.try_get("tx_status")?;
    let escrow_status: String = row.try_get("escrow_status")?;
    if tx_status != "disputed" || escrow_status != "disputed" {
        return Err(AppError::Conflict(format!(
            "Transaction is '{tx_status}' (escrow '{escrow_status}'), not 'disputed'"
        )));
    }

    let listing_id: Uuid = row.try_get("listing_id")?;
    let amount: i64 = row.try_get("amount")?;
    let payment_reference: String = row.try_get("payment_reference")?;
    let phone = refund_phone(phone_override, row.try_get("payer_phone")?)?;
    check_payout_minimum(amount)?;

    let external_id = refund_external_id("escrow_refund", &payment_reference)?;
    let trans_id = pay_once(
        state,
        Some(tx_id),
        amount,
        &phone,
        &external_id,
        &format!("BookBridge refund for listing {listing_id}"),
    )
    .await?;

    let now = Utc::now();
    let mut db = state.pool.begin().await?;
    let escrow = sqlx::query(
        "UPDATE escrow_transactions SET status = 'refunded', updated_at = $2 \
         WHERE transaction_id = $1 AND status = 'disputed'",
    )
    .bind(tx_id)
    .bind(now)
    .execute(&mut *db)
    .await?;
    let tx = sqlx::query(
        "UPDATE transactions SET status = 'refunded' WHERE id = $1 AND status = 'disputed'",
    )
    .bind(tx_id)
    .execute(&mut *db)
    .await?;
    if escrow.rows_affected() != 1 || tx.rows_affected() != 1 {
        // The payout went out; a retry finds it on Fapshi and only redoes this.
        db.rollback().await?;
        return Err(AppError::Conflict(format!(
            "Refund {trans_id} was paid but transaction {tx_id} changed state; retry to record it"
        )));
    }
    record_admin_action(&mut db, decision, Some(tx_id), None, Some(&trans_id)).await?;
    db.commit().await?;

    Ok(trans_id)
}

pub async fn list_unmatched_handler(
    State(state): State<AppState>,
    _admin: AdminUser,
) -> Result<Json<UnmatchedPaymentList>, AppError> {
    let rows = sqlx::query(
        "SELECT l.id, l.request_payload, l.created_at, pp.phone AS payer_phone \
         FROM fapshi_audit_logs l \
         LEFT JOIN payment_payers pp ON pp.payment_reference = l.request_payload->>'transId' \
         WHERE l.endpoint = $1 \
           AND NOT EXISTS (SELECT 1 FROM admin_actions a WHERE a.audit_log_id = l.id) \
         ORDER BY l.created_at ASC \
         LIMIT $2",
    )
    .bind(UNMATCHED_ENDPOINT)
    .bind(LIST_LIMIT)
    .fetch_all(&state.pool)
    .await?;

    rows.into_iter()
        .map(|row| {
            let payload: Option<serde_json::Value> = row.try_get("request_payload")?;
            let field = |key: &str| payload.as_ref().and_then(|p| p.get(key)).cloned();
            Ok(UnmatchedPayment {
                id: row.try_get("id")?,
                trans_id: field("transId").and_then(|v| v.as_str().map(str::to_string)),
                amount: field("amount").and_then(|v| v.as_f64()),
                external_id: field("externalId").and_then(|v| v.as_str().map(str::to_string)),
                reason: field("reason").and_then(|v| v.as_str().map(str::to_string)),
                received_at: row.try_get("created_at")?,
                payer_phone_hint: row
                    .try_get::<Option<String>, _>("payer_phone")?
                    .as_deref()
                    .map(mask_phone),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()
        .map(|payments| Json(UnmatchedPaymentList { payments }))
}

pub async fn refund_unmatched_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(log_id): Path<Uuid>,
    Json(request): Json<ResolveRequest>,
) -> Result<Json<ResolveResponse>, AppError> {
    let note = validate_note(&request.note)?;
    let phone_override = request.phone.as_deref().map(validate_phone).transpose()?;
    let decision = AdminDecision {
        admin_id,
        action: "refund_unmatched",
        note: &note,
    };
    let trans_id = refund_unmatched(&state, log_id, phone_override, &decision).await?;
    Ok(Json(ResolveResponse {
        ok: true,
        payout_reference: Some(trans_id),
    }))
}

pub async fn dismiss_unmatched_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(log_id): Path<Uuid>,
    Json(request): Json<ResolveRequest>,
) -> Result<Json<ResolveResponse>, AppError> {
    let note = validate_note(&request.note)?;
    if request.phone.is_some() {
        return Err(AppError::BadRequest(
            "phone only applies to refunds".to_string(),
        ));
    }
    let _guard = claim(&state, log_id)?;
    load_open_unmatched(&state, log_id).await?;
    let decision = AdminDecision {
        admin_id,
        action: "dismiss_unmatched",
        note: &note,
    };
    let mut db = state.pool.begin().await?;
    record_admin_action(&mut db, &decision, None, Some(log_id), None).await?;
    db.commit().await?;
    Ok(Json(ResolveResponse {
        ok: true,
        payout_reference: None,
    }))
}

/// Refunds an unmatched payment to the number that paid. The amount comes
/// from Fapshi's own record of the collection, not from our log.
pub(crate) async fn refund_unmatched(
    state: &AppState,
    log_id: Uuid,
    phone_override: Option<String>,
    decision: &AdminDecision<'_>,
) -> Result<String, AppError> {
    let _guard = claim(state, log_id)?;
    let (collection_id, payer_phone) = load_open_unmatched(state, log_id).await?;
    let phone = refund_phone(phone_override, payer_phone)?;

    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());
    let collection = fapshi.payment_status(&state.pool, &collection_id).await?;
    let status = collection.status.unwrap_or_default().to_uppercase();
    if status != "SUCCESSFUL" {
        return Err(AppError::Conflict(format!(
            "Fapshi reports collection {collection_id} as '{status}', not SUCCESSFUL; nothing to refund"
        )));
    }
    let amount = collection.amount.map(|a| a.floor() as i64).ok_or_else(|| {
        AppError::Fapshi(format!("Fapshi returned no amount for {collection_id}"))
    })?;
    check_payout_minimum(amount)?;

    let external_id = refund_external_id("unmatched_refund", &collection_id)?;
    let trans_id = pay_once(
        state,
        None,
        amount,
        &phone,
        &external_id,
        "BookBridge refund of an unmatched payment",
    )
    .await?;

    let mut db = state.pool.begin().await?;
    record_admin_action(&mut db, decision, None, Some(log_id), Some(&trans_id)).await?;
    db.commit().await?;
    Ok(trans_id)
}

/// Returns the collection transId and recorded payer number of an
/// unresolved unmatched payment.
async fn load_open_unmatched(
    state: &AppState,
    log_id: Uuid,
) -> Result<(String, Option<String>), AppError> {
    let row = sqlx::query(
        "SELECT l.request_payload->>'transId' AS trans_id, pp.phone AS payer_phone, \
                EXISTS (SELECT 1 FROM admin_actions a WHERE a.audit_log_id = l.id) AS resolved \
         FROM fapshi_audit_logs l \
         LEFT JOIN payment_payers pp ON pp.payment_reference = l.request_payload->>'transId' \
         WHERE l.id = $1 AND l.endpoint = $2",
    )
    .bind(log_id)
    .bind(UNMATCHED_ENDPOINT)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Unmatched payment {log_id} not found")))?;

    let resolved: bool = row.try_get("resolved")?;
    if resolved {
        return Err(AppError::Conflict(format!(
            "Unmatched payment {log_id} is already resolved"
        )));
    }
    let trans_id: Option<String> = row.try_get("trans_id")?;
    let trans_id = trans_id.filter(|t| !t.is_empty()).ok_or_else(|| {
        AppError::BadRequest("Unmatched payment has no Fapshi transId".to_string())
    })?;
    crate::routes::payments::validate_trans_id(&trans_id)?;
    Ok((trans_id, row.try_get("payer_phone")?))
}

/// What to do about a refund, given the payouts Fapshi already holds under
/// its externalId.
#[derive(Debug, PartialEq, Eq)]
pub enum RefundPayout {
    /// Nothing usable exists yet (none, or only failed/expired attempts).
    Pay,
    /// Already paid; this is the payout's transId.
    AlreadyPaid(String),
    /// A payout is still in flight (or in a state we don't recognise);
    /// paying again could pay twice.
    InFlight { trans_id: String, status: String },
}

pub fn decide_refund_payout(existing: &[FapshiSearchItem]) -> RefundPayout {
    let status_of = |item: &FapshiSearchItem| item.status.trim().to_uppercase();
    if let Some(paid) = existing
        .iter()
        .find(|item| matches!(status_of(item).as_str(), "SUCCESSFUL" | "SUCCESS"))
    {
        return RefundPayout::AlreadyPaid(paid.trans_id.clone());
    }
    match existing
        .iter()
        .find(|item| !matches!(status_of(item).as_str(), "FAILED" | "EXPIRED"))
    {
        Some(open) => RefundPayout::InFlight {
            trans_id: open.trans_id.clone(),
            status: open.status.clone(),
        },
        None => RefundPayout::Pay,
    }
}

/// Pays `amount` unless Fapshi already holds a payout with this externalId
/// that succeeded or may still succeed; returns the payout's transId. Fails
/// closed if Fapshi can't be asked.
async fn pay_once(
    state: &AppState,
    tx_id: Option<Uuid>,
    amount: i64,
    phone: &str,
    external_id: &str,
    message: &str,
) -> Result<String, AppError> {
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());
    let existing = fapshi
        .search_by_external_id(&state.pool, external_id)
        .await?;
    match decide_refund_payout(&existing) {
        RefundPayout::AlreadyPaid(trans_id) => {
            tracing::info!(
                "Refund {} already paid on Fapshi ({}); not paying again",
                external_id,
                trans_id
            );
            Ok(trans_id)
        }
        RefundPayout::InFlight { trans_id, status } => Err(AppError::Conflict(format!(
            "Refund payout {trans_id} is '{status}' on Fapshi; wait for it to settle, then retry"
        ))),
        RefundPayout::Pay => {
            fapshi
                .execute_payout(
                    &state.pool,
                    tx_id,
                    amount as f64,
                    phone,
                    "BookBridge Buyer",
                    external_id,
                    message,
                )
                .await
        }
    }
}

fn claim(state: &AppState, id: Uuid) -> Result<InProgressGuard, AppError> {
    InProgressGuard::claim(state, id).map_err(|e| match e {
        AppError::BadRequest(_) => {
            AppError::Conflict("Another action on this item is in progress".to_string())
        }
        other => other,
    })
}

pub fn validate_note(raw: &str) -> Result<String, AppError> {
    let note = raw.trim();
    if note.is_empty() {
        return Err(AppError::BadRequest("note is required".to_string()));
    }
    if note.chars().count() > MAX_NOTE_CHARS {
        return Err(AppError::BadRequest(format!(
            "note must be at most {MAX_NOTE_CHARS} characters"
        )));
    }
    Ok(note.to_string())
}

/// The admin's number wins; otherwise the one recorded at checkout.
pub fn refund_phone(
    phone_override: Option<String>,
    recorded: Option<String>,
) -> Result<String, AppError> {
    phone_override
        .or_else(|| recorded.filter(|p| !p.trim().is_empty()))
        .ok_or_else(|| {
            AppError::BadRequest(
                "No payer number on record for this payment; enter the number to refund"
                    .to_string(),
            )
        })
}

pub fn check_payout_minimum(amount: i64) -> Result<(), AppError> {
    if amount < MIN_AMOUNT_XAF {
        return Err(AppError::BadRequest(format!(
            "{amount} XAF is below Fapshi's {MIN_AMOUNT_XAF} XAF payout minimum; dismiss it and refund by hand"
        )));
    }
    Ok(())
}

pub fn refund_external_id(prefix: &str, reference: &str) -> Result<String, AppError> {
    let id = format!("{prefix}_{reference}");
    let valid = id.len() <= MAX_EXTERNAL_ID_CHARS
        && id
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_');
    if valid {
        Ok(id)
    } else {
        Err(AppError::BadRequest(format!(
            "Payment reference {reference} can't be used in a Fapshi externalId"
        )))
    }
}

/// Shows only the first and last three digits, e.g. `677•••456`.
pub fn mask_phone(phone: &str) -> String {
    let digits: Vec<char> = phone.chars().filter(|c| c.is_ascii_digit()).collect();
    if digits.len() < 7 {
        return "•••".to_string();
    }
    let head: String = digits[..3].iter().collect();
    let tail: String = digits[digits.len() - 3..].iter().collect();
    format!("{head}•••{tail}")
}
