//! App-facing payment endpoints. The server decides what is charged: a
//! purchase costs the listing's price and a boost has a fixed price, so the
//! app never holds Fapshi credentials or chooses the amount. The collection
//! account's keys are read from `app_secrets`, like the payout keys.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::AppError;
use crate::fapshi::{DirectPayRequest, FapshiClient};
use crate::user_auth::AuthenticatedUser;
use crate::AppState;

/// Fapshi rejects collections below 100 XAF.
pub const MIN_AMOUNT_XAF: i64 = 100;
pub const MAX_DONATION_XAF: i64 = 1_000_000;
pub const BOOST_PRICE_XAF: i64 = 500;
pub const BOOST_DAYS: i32 = 7;
const MAX_TRANS_ID_CHARS: usize = 100;

#[derive(Deserialize, Debug, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum PaymentPurpose {
    Purchase { listing_id: Uuid },
    Boost { listing_id: Uuid },
    Donation { amount: i64 },
}

#[derive(Deserialize, Debug)]
pub struct InitiatePaymentRequest {
    #[serde(flatten)]
    pub purpose: PaymentPurpose,
    pub phone: String,
    pub medium: Option<String>,
}

#[derive(Serialize)]
pub struct InitiatePaymentResponse {
    pub trans_id: String,
}

#[derive(Serialize)]
pub struct PaymentStatusResponse {
    pub status: String,
}

/// What a Fapshi `externalId` says a payment was for.
#[derive(Debug, PartialEq)]
pub enum ExternalRef {
    Purchase { listing_id: Uuid, buyer_id: Uuid },
    Boost { listing_id: Uuid },
    Donation { user_id: Option<Uuid> },
}

pub fn payment_routes() -> Router<AppState> {
    Router::new()
        .route("/payments/initiate", post(initiate_payment_handler))
        .route("/payments/status/:trans_id", get(payment_status_handler))
}

pub async fn initiate_payment_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
    Json(request): Json<InitiatePaymentRequest>,
) -> Result<Json<InitiatePaymentResponse>, AppError> {
    let phone = validate_phone(&request.phone)?;
    let medium = validate_medium(request.medium.as_deref())?;
    let now = Utc::now();
    let millis = now.timestamp_millis();
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());

    let trans_id = match request.purpose {
        PaymentPurpose::Purchase { listing_id } => {
            let listing = load_listing(&state.pool, listing_id).await?;
            if listing.seller_id == user_id {
                return Err(AppError::BadRequest(
                    "You cannot buy your own listing".to_string(),
                ));
            }
            if listing.status != "available" {
                return Err(AppError::Conflict(
                    "This listing is no longer available".to_string(),
                ));
            }
            if listing.price < MIN_AMOUNT_XAF {
                return Err(AppError::BadRequest(format!(
                    "Listings priced below {MIN_AMOUNT_XAF} XAF cannot be paid online"
                )));
            }
            let pay = DirectPayRequest {
                amount: listing.price,
                phone,
                medium,
                external_id: purchase_external_id(listing_id, user_id, millis),
                message: "BookBridge book purchase".to_string(),
            };
            let trans_id = fapshi.direct_pay(&state.pool, &pay).await?;
            // The payment prompt is already on the buyer's phone, so a failed
            // insert must not hide the transId. The webhook re-validates
            // against the listing price when no pending row exists.
            if let Err(e) = record_pending_purchase(
                &state.pool,
                &trans_id,
                listing_id,
                user_id,
                listing.seller_id,
                listing.price,
                now,
            )
            .await
            {
                tracing::error!(
                    "Failed to record pending purchase {} for listing {}: {:?}",
                    trans_id,
                    listing_id,
                    e
                );
            }
            trans_id
        }
        PaymentPurpose::Boost { listing_id } => {
            let listing = load_listing(&state.pool, listing_id).await?;
            if listing.seller_id != user_id {
                return Err(AppError::NotFound(format!(
                    "Listing {listing_id} not found"
                )));
            }
            let pay = DirectPayRequest {
                amount: BOOST_PRICE_XAF,
                phone,
                medium,
                external_id: boost_external_id(listing_id, millis),
                message: format!("BookBridge listing boost ({BOOST_DAYS} days)"),
            };
            fapshi.direct_pay(&state.pool, &pay).await?
        }
        PaymentPurpose::Donation { amount } => {
            validate_donation_amount(amount)?;
            let pay = DirectPayRequest {
                amount,
                phone,
                medium,
                external_id: donation_external_id(user_id, millis),
                message: "Donation to BookBridge".to_string(),
            };
            fapshi.direct_pay(&state.pool, &pay).await?
        }
    };

    Ok(Json(InitiatePaymentResponse { trans_id }))
}

/// Payments that aren't the caller's get the same 404 as unknown ones.
pub async fn payment_status_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
    Path(trans_id): Path<String>,
) -> Result<Json<PaymentStatusResponse>, AppError> {
    validate_trans_id(&trans_id)?;
    let fapshi = FapshiClient::new(state.fapshi_base_url.clone());
    let payment = fapshi.payment_status(&state.pool, &trans_id).await?;

    let not_found = || AppError::NotFound(format!("Payment {trans_id} not found"));
    let owner_ok = match payment.external_id.as_deref().and_then(parse_external_ref) {
        Some(ExternalRef::Purchase { buyer_id, .. }) => buyer_id == user_id,
        Some(ExternalRef::Donation { user_id: donor }) => donor == Some(user_id),
        Some(ExternalRef::Boost { listing_id }) => {
            load_listing(&state.pool, listing_id).await?.seller_id == user_id
        }
        None => false,
    };
    if !owner_ok {
        return Err(not_found());
    }

    Ok(Json(PaymentStatusResponse {
        status: payment.status.unwrap_or_default().to_uppercase(),
    }))
}

struct ListingForPayment {
    seller_id: Uuid,
    price: i64,
    status: String,
}

async fn load_listing(pool: &PgPool, listing_id: Uuid) -> Result<ListingForPayment, AppError> {
    let row = sqlx::query(
        "SELECT seller_id, price_fcfa::bigint AS price, status FROM listings WHERE id = $1",
    )
    .bind(listing_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Listing {listing_id} not found")))?;

    Ok(ListingForPayment {
        seller_id: row.try_get("seller_id")?,
        price: row.try_get::<Option<i64>, _>("price")?.unwrap_or(0),
        status: row
            .try_get::<Option<String>, _>("status")?
            .unwrap_or_default(),
    })
}

async fn record_pending_purchase(
    pool: &PgPool,
    trans_id: &str,
    listing_id: Uuid,
    buyer_id: Uuid,
    seller_id: Uuid,
    price: i64,
    now: DateTime<Utc>,
) -> Result<(), AppError> {
    let amount = price as f64;
    sqlx::query(
        "INSERT INTO transactions ( \
            payment_reference, listing_id, buyer_id, seller_id, amount, status, \
            payout_status, payout_reference, commission_amount, created_at \
         ) \
         VALUES ($1, $2, $3, $4, $5, 'pending_payment', 'pending', NULL, $6, $7) \
         ON CONFLICT (payment_reference) DO NOTHING",
    )
    .bind(trans_id)
    .bind(listing_id)
    .bind(buyer_id)
    .bind(seller_id)
    .bind(amount)
    .bind(commission_for(amount))
    .bind(now)
    .execute(pool)
    .await?;
    Ok(())
}

/// BookBridge keeps 5%; the seller's payout is rounded down to whole XAF.
pub fn commission_for(amount: f64) -> f64 {
    amount - (amount * 0.95).floor()
}

/// What the seller receives on release. Fapshi rejects payouts below
/// `MIN_AMOUNT_XAF`, so for small sales the commission shrinks to keep the
/// payout at that minimum. `None` if the sale itself is below the minimum.
pub fn seller_payout(amount: f64, commission: f64) -> Option<f64> {
    let min = MIN_AMOUNT_XAF as f64;
    if amount < min {
        return None;
    }
    Some((amount - commission).max(min))
}

/// Whether a payment covers what was expected, allowing for float rounding.
pub fn covers_expected(paid: f64, expected: f64) -> bool {
    paid + 0.000_001 >= expected
}

/// Normalises a Cameroonian mobile number to the 9-digit form Fapshi expects.
pub fn validate_phone(raw: &str) -> Result<String, AppError> {
    let phone = FapshiClient::clean_phone(raw);
    if phone.len() == 9 && phone.starts_with('6') {
        Ok(phone)
    } else {
        Err(AppError::BadRequest(
            "Enter a 9-digit Cameroonian mobile number starting with 6".to_string(),
        ))
    }
}

pub fn validate_medium(raw: Option<&str>) -> Result<Option<String>, AppError> {
    match raw.map(|m| m.trim().to_lowercase()) {
        None => Ok(None),
        Some(m) if m.is_empty() => Ok(None),
        Some(m) if m == "mobile money" || m == "orange money" => Ok(Some(m)),
        Some(_) => Err(AppError::BadRequest(
            "medium must be 'mobile money' or 'orange money'".to_string(),
        )),
    }
}

pub fn validate_donation_amount(amount: i64) -> Result<(), AppError> {
    if (MIN_AMOUNT_XAF..=MAX_DONATION_XAF).contains(&amount) {
        Ok(())
    } else {
        Err(AppError::BadRequest(format!(
            "Donations must be between {MIN_AMOUNT_XAF} and {MAX_DONATION_XAF} XAF"
        )))
    }
}

/// transIds go into a Fapshi URL path, so only Fapshi's own id alphabet is allowed.
pub fn validate_trans_id(trans_id: &str) -> Result<(), AppError> {
    let ok = !trans_id.is_empty()
        && trans_id.len() <= MAX_TRANS_ID_CHARS
        && trans_id
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_');
    if ok {
        Ok(())
    } else {
        Err(AppError::BadRequest(
            "Invalid payment reference".to_string(),
        ))
    }
}

// Fapshi only accepts externalIds matching ^[a-zA-Z0-9-_]{1,100}$, so the
// separator is '_' (UUIDs only contain hex digits and '-').
pub fn purchase_external_id(listing_id: Uuid, buyer_id: Uuid, millis: i64) -> String {
    format!("purchase_{listing_id}_{buyer_id}_{millis}")
}

pub fn boost_external_id(listing_id: Uuid, millis: i64) -> String {
    format!("boost_{listing_id}_{BOOST_DAYS}_{millis}")
}

pub fn donation_external_id(user_id: Uuid, millis: i64) -> String {
    format!("donation_{user_id}_{millis}")
}

/// Parses externalIds in both the current `_` form and the older `:` form.
pub fn parse_external_ref(external_id: &str) -> Option<ExternalRef> {
    let separator = if external_id.contains(':') { ':' } else { '_' };
    let parts: Vec<&str> = external_id.split(separator).collect();
    let uuid_at = |i: usize| parts.get(i).and_then(|p| Uuid::parse_str(p).ok());
    match parts.first().copied()? {
        "purchase" => Some(ExternalRef::Purchase {
            listing_id: uuid_at(1)?,
            buyer_id: uuid_at(2)?,
        }),
        "boost" => Some(ExternalRef::Boost {
            listing_id: uuid_at(1)?,
        }),
        "donation" => match parts.get(1).copied()? {
            "anonymous" => Some(ExternalRef::Donation { user_id: None }),
            _ => Some(ExternalRef::Donation {
                user_id: Some(uuid_at(1)?),
            }),
        },
        _ => None,
    }
}
