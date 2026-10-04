//! Age-based ID verification rules (#34, #36).
//!
//! Both parties to a new purchase must be verified. A verified
//! user aged 10-14 transacts through their guardian's Mobile Money number,
//! which was checked by an admin against the guardian's CNI.

use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::AppError;

pub const VERIFIED: &str = "verified";

/// Users younger than this pay and get paid through their guardian.
pub const GUARDIAN_AGE_LIMIT: i32 = 15;

/// The verification facts needed to decide what a user may do.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Verification {
    pub status: String,
    pub age: Option<i32>,
    pub guardian_phone: Option<String>,
}

impl Verification {
    pub fn is_verified(&self) -> bool {
        self.status == VERIFIED
    }

    /// The guardian's number if this user must transact through a guardian.
    pub fn guardian_number(&self) -> Option<&str> {
        if !self.is_verified() {
            return None;
        }
        match (self.age, self.guardian_phone.as_deref()) {
            (Some(age), Some(phone)) if age < GUARDIAN_AGE_LIMIT && !phone.trim().is_empty() => {
                Some(phone)
            }
            _ => None,
        }
    }
}

const VERIFICATION_COLUMNS: &str = "id_verification_status, guardian_phone, \
     date_part('year', age(current_date, date_of_birth))::int AS age";

pub async fn load_verification(pool: &PgPool, user_id: Uuid) -> Result<Verification, AppError> {
    let row = sqlx::query(&format!(
        "SELECT {VERIFICATION_COLUMNS} FROM profiles WHERE id = $1"
    ))
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::Forbidden("Profile not found".to_string()))?;

    Ok(Verification {
        status: row.get("id_verification_status"),
        age: row.get("age"),
        guardian_phone: row.get("guardian_phone"),
    })
}

/// Checks that a purchase may go ahead: both parties are verified, and a
/// buyer under 15 pays from their guardian's number. `phone` is the cleaned
/// 9-digit number the buyer is paying from.
pub async fn check_purchase_allowed(
    pool: &PgPool,
    buyer_id: Uuid,
    seller_id: Uuid,
    phone: &str,
) -> Result<(), AppError> {
    let buyer = load_verification(pool, buyer_id).await?;
    let seller = load_verification(pool, seller_id).await?;
    purchase_decision(&buyer, &seller, phone)
}

/// Pure decision behind [`check_purchase_allowed`].
pub fn purchase_decision(
    buyer: &Verification,
    seller: &Verification,
    phone: &str,
) -> Result<(), AppError> {
    if !buyer.is_verified() {
        return Err(AppError::Forbidden(
            "Verify your identity before buying books".to_string(),
        ));
    }
    if !seller.is_verified() {
        return Err(AppError::Forbidden(
            "This seller has not verified their identity yet".to_string(),
        ));
    }
    if let Some(guardian) = buyer.guardian_number() {
        if guardian != phone {
            return Err(AppError::Forbidden(
                "Pay with your parent or guardian's registered Mobile Money number".to_string(),
            ));
        }
    }
    Ok(())
}

/// The number a seller's escrow payout goes to: their guardian's if they
/// are verified and under 15, otherwise their own WhatsApp/Mobile Money
/// number. Verification is not required here: new sales already need a
/// verified seller, and sales paid before verification shipped are
/// grandfathered.
pub fn payout_phone(seller: &Verification, whatsapp: Option<&str>) -> Result<String, AppError> {
    if let Some(guardian) = seller.guardian_number() {
        return Ok(guardian.to_string());
    }
    match whatsapp {
        Some(num) if !num.trim().is_empty() => Ok(num.to_string()),
        _ => Err(AppError::BadRequest(
            "Seller has no payout number configured".to_string(),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn user(status: &str, age: Option<i32>, guardian: Option<&str>) -> Verification {
        Verification {
            status: status.to_string(),
            age,
            guardian_phone: guardian.map(str::to_string),
        }
    }

    #[test]
    fn unverified_buyer_is_forbidden() {
        let buyer = user("pending", Some(20), None);
        let seller = user(VERIFIED, Some(20), None);
        assert!(matches!(
            purchase_decision(&buyer, &seller, "670000000"),
            Err(AppError::Forbidden(_))
        ));
    }

    #[test]
    fn unverified_seller_is_forbidden() {
        let buyer = user(VERIFIED, Some(20), None);
        let seller = user("unverified", None, None);
        assert!(matches!(
            purchase_decision(&buyer, &seller, "670000000"),
            Err(AppError::Forbidden(_))
        ));
    }

    #[test]
    fn young_buyer_must_use_guardian_phone() {
        let buyer = user(VERIFIED, Some(12), Some("690000000"));
        let seller = user(VERIFIED, Some(20), None);
        assert!(matches!(
            purchase_decision(&buyer, &seller, "670000000"),
            Err(AppError::Forbidden(_))
        ));
        assert!(purchase_decision(&buyer, &seller, "690000000").is_ok());
    }

    #[test]
    fn older_buyer_may_use_any_phone() {
        let buyer = user(VERIFIED, Some(16), None);
        let seller = user(VERIFIED, Some(12), Some("690000000"));
        assert!(purchase_decision(&buyer, &seller, "670000000").is_ok());
    }

    #[test]
    fn young_seller_is_paid_to_guardian() {
        let seller = user(VERIFIED, Some(14), Some("690000000"));
        assert_eq!(
            payout_phone(&seller, Some("670000000")).unwrap(),
            "690000000"
        );
    }

    #[test]
    fn seller_who_turned_fifteen_is_paid_directly() {
        let seller = user(VERIFIED, Some(15), Some("690000000"));
        assert_eq!(
            payout_phone(&seller, Some("670000000")).unwrap(),
            "670000000"
        );
    }

    #[test]
    fn grandfathered_unverified_seller_is_paid_directly() {
        let seller = user("unverified", None, None);
        assert_eq!(
            payout_phone(&seller, Some("670000000")).unwrap(),
            "670000000"
        );
    }

    #[test]
    fn unverified_guardian_phone_is_ignored() {
        let seller = user("pending", Some(12), Some("690000000"));
        assert_eq!(
            payout_phone(&seller, Some("670000000")).unwrap(),
            "670000000"
        );
    }

    #[test]
    fn verified_seller_without_number_is_not_paid() {
        let seller = user(VERIFIED, Some(20), None);
        assert!(payout_phone(&seller, Some("  ")).is_err());
        assert!(payout_phone(&seller, None).is_err());
    }
}
