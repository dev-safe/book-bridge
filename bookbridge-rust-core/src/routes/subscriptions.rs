//! Power Seller checkout (#39). The app mints a short-lived, single-use
//! upgrade code for the signed-in user and opens the landing page with it;
//! the page redeems the code to start a Fapshi payment without a web login.
//! The webhook grants the tier once Fapshi confirms the payment.

use axum::{
    extract::{Query, State},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::error::AppError;
use crate::fapshi::{DirectPayRequest, FapshiClient};
use crate::rate_limit::too_many_requests;
use crate::routes::payments::{
    record_payer, subscription_external_id, validate_medium, validate_phone, SUBSCRIPTION_DAYS,
    SUBSCRIPTION_PRICE_XAF,
};
use crate::user_auth::AuthenticatedUser;
use crate::AppState;

pub const UPGRADE_CODE_MINUTES: i32 = 15;

#[derive(Serialize)]
pub struct UpgradeCodeResponse {
    pub code: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct InitiateSubscriptionRequest {
    pub code: String,
    pub phone: String,
    pub medium: Option<String>,
}

#[derive(Deserialize)]
pub struct CodeQuery {
    pub code: String,
}

#[derive(Serialize)]
pub struct SubscriptionStatusResponse {
    /// `UNUSED` or `EXPIRED` before a payment starts, otherwise Fapshi's
    /// status (e.g. `PENDING`, `SUCCESSFUL`, `FAILED`).
    pub status: String,
    pub price_xaf: i64,
    pub days: i32,
}

pub fn subscription_routes() -> Router<AppState> {
    Router::new()
        .route(
            "/subscriptions/upgrade-code",
            post(create_upgrade_code_handler),
        )
        .route(
            "/subscriptions/initiate",
            post(initiate_subscription_handler),
        )
        .route("/subscriptions/status", get(subscription_status_handler))
}

/// Codes are `Uuid::simple()` strings: 32 lowercase hex characters.
pub fn validate_upgrade_code(code: &str) -> Result<(), AppError> {
    let ok = code.len() == 32
        && code
            .chars()
            .all(|c| c.is_ascii_digit() || ('a'..='f').contains(&c));
    if ok {
        Ok(())
    } else {
        Err(AppError::BadRequest("Invalid upgrade link".to_string()))
    }
}

pub async fn create_upgrade_code_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
) -> Result<Json<UpgradeCodeResponse>, AppError> {
    let code = Uuid::new_v4().simple().to_string();
    let row = sqlx::query(
        "INSERT INTO upgrade_codes (code, user_id, expires_at) \
         SELECT $1, p.id, now() + make_interval(mins => $3) FROM profiles p WHERE p.id = $2 \
         RETURNING expires_at",
    )
    .bind(&code)
    .bind(user_id)
    .bind(UPGRADE_CODE_MINUTES)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Profile not found".to_string()))?;

    Ok(Json(UpgradeCodeResponse {
        code,
        expires_at: row.try_get("expires_at")?,
    }))
}

fn link_unusable() -> AppError {
    AppError::Conflict(
        "This upgrade link has expired or was already used. Start again from the BookBridge app."
            .to_string(),
    )
}

pub async fn initiate_subscription_handler(
    State(state): State<AppState>,
    Json(request): Json<InitiateSubscriptionRequest>,
) -> Result<Json<SubscriptionStatusResponse>, AppError> {
    validate_upgrade_code(&request.code)?;
    let phone = validate_phone(&request.phone)?;
    let medium = validate_medium(request.medium.as_deref())?;

    let user_id: Uuid = sqlx::query(
        "SELECT user_id FROM upgrade_codes \
         WHERE code = $1 AND used_at IS NULL AND expires_at > now()",
    )
    .bind(&request.code)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(link_unusable)?
    .try_get("user_id")?;

    // Each initiation sends a mobile-money prompt to a phone.
    if let Err(retry_after) = state.rate_limits.payment_initiations.check(&user_id) {
        tracing::warn!(%user_id, "Subscription initiation rate limit hit");
        return Err(too_many_requests(retry_after));
    }

    // Claiming is atomic, so two parallel submits can't both charge.
    let claimed = sqlx::query(
        "UPDATE upgrade_codes SET used_at = now() \
         WHERE code = $1 AND used_at IS NULL AND expires_at > now() \
         RETURNING user_id",
    )
    .bind(&request.code)
    .fetch_optional(&state.pool)
    .await?;
    if claimed.is_none() {
        return Err(link_unusable());
    }

    let pay = DirectPayRequest {
        amount: SUBSCRIPTION_PRICE_XAF,
        phone: phone.clone(),
        medium,
        external_id: subscription_external_id(user_id, Utc::now().timestamp_millis()),
        message: format!("BookBridge Power Seller ({SUBSCRIPTION_DAYS} days)"),
    };
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());
    let trans_id = match fapshi.direct_pay(&state.pool, &pay).await {
        Ok(id) => id,
        Err(e) => {
            // No prompt was sent, so the user may retry with the same link.
            if let Err(unclaim_err) = sqlx::query(
                "UPDATE upgrade_codes SET used_at = NULL WHERE code = $1 AND trans_id IS NULL",
            )
            .bind(&request.code)
            .execute(&state.pool)
            .await
            {
                tracing::error!("Failed to release upgrade code: {:?}", unclaim_err);
            }
            return Err(e);
        }
    };

    // The prompt is already on the phone, so failed bookkeeping is logged,
    // not returned: the webhook grants the tier from the externalId alone.
    if let Err(e) = sqlx::query("UPDATE upgrade_codes SET trans_id = $2 WHERE code = $1")
        .bind(&request.code)
        .bind(&trans_id)
        .execute(&state.pool)
        .await
    {
        tracing::error!(
            "Failed to store transId {} on upgrade code: {:?}",
            trans_id,
            e
        );
    }
    if let Err(e) = record_payer(&state.pool, &trans_id, &phone).await {
        tracing::error!("Failed to record payer for payment {}: {:?}", trans_id, e);
    }

    Ok(Json(status_response("PENDING")))
}

pub async fn subscription_status_handler(
    State(state): State<AppState>,
    Query(query): Query<CodeQuery>,
) -> Result<Json<SubscriptionStatusResponse>, AppError> {
    validate_upgrade_code(&query.code)?;
    let row = sqlx::query(
        "SELECT used_at IS NOT NULL AS used, expires_at <= now() AS expired, trans_id \
         FROM upgrade_codes WHERE code = $1",
    )
    .bind(&query.code)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Upgrade link not found".to_string()))?;

    let used: bool = row.try_get("used")?;
    let expired: bool = row.try_get("expired")?;
    let trans_id: Option<String> = row.try_get("trans_id")?;

    let status = match (trans_id, used, expired) {
        (Some(trans_id), _, _) => {
            let fapshi = FapshiClient::new(state.fapshi_base_url.clone());
            fapshi
                .payment_status(&state.pool, &trans_id)
                .await?
                .status
                .unwrap_or_default()
                .to_uppercase()
        }
        // Claimed but the transId isn't stored yet (or failed to store).
        (None, true, _) => "PENDING".to_string(),
        (None, false, true) => "EXPIRED".to_string(),
        (None, false, false) => "UNUSED".to_string(),
    };
    Ok(Json(status_response(&status)))
}

fn status_response(status: &str) -> SubscriptionStatusResponse {
    SubscriptionStatusResponse {
        status: status.to_string(),
        price_xaf: SUBSCRIPTION_PRICE_XAF,
        days: SUBSCRIPTION_DAYS,
    }
}
