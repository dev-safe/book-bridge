//! In-app account deletion (Google Play account-deletion requirement).
//!
//! A hard delete of `auth.users` is not possible: transactions, reviews,
//! messages and listings reference it, and deleting buyer/seller rows would
//! wipe the other party's purchase history. Instead the account is closed:
//! personal data and uploaded files are deleted, the profile is anonymised to
//! "Deleted user", the login is scrubbed and banned, and completed orders are
//! kept (anonymised) as the other party's and our financial record.

use axum::{extract::State, http::HeaderMap, routing::post, Json, Router};
use serde::Serialize;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::error::AppError;
use crate::routes::id_verification::ID_DOCUMENTS_BUCKET;
use crate::user_auth::{bearer_token, AuthenticatedUser};
use crate::AppState;

/// Buckets whose `{user_id}/` folder holds the user's uploads.
pub const USER_BUCKETS: [&str; 3] = ["book_images", "profiles", ID_DOCUMENTS_BUCKET];

pub const DELETED_USER_NAME: &str = "Deleted user";

pub const ACTIVE_ORDERS_MESSAGE: &str =
    "You have an order in progress. Finish or cancel it before deleting your account.";

#[derive(Serialize)]
pub struct DeleteAccountResponse {
    pub ok: bool,
}

pub fn account_routes() -> Router<AppState> {
    Router::new().route("/account/delete", post(delete_account_handler))
}

/// Locks the user's profile and listings, refuses while an order is open,
/// deletes their files, then anonymises everything in one transaction. If a
/// Storage delete fails nothing is written, so the user can retry.
pub async fn delete_account_handler(
    State(state): State<AppState>,
    AuthenticatedUser(user_id): AuthenticatedUser,
    headers: HeaderMap,
) -> Result<Json<DeleteAccountResponse>, AppError> {
    let token = bearer_token(&headers)?;

    let mut tx = state.pool.begin().await?;
    lock_account(&mut tx, user_id).await?;
    if has_open_orders(&mut tx, user_id).await? {
        return Err(AppError::Conflict(ACTIVE_ORDERS_MESSAGE.to_string()));
    }

    let folder = user_id.to_string();
    for bucket in USER_BUCKETS {
        state
            .supabase_auth
            .purge_storage_folder(token, bucket, &folder)
            .await?;
    }

    delete_personal_rows(&mut tx, user_id).await?;
    close_listings(&mut tx, user_id).await?;
    anonymise_profile(&mut tx, user_id).await?;
    close_login(&mut tx, user_id).await?;
    tx.commit().await?;

    tracing::info!(%user_id, "Account deleted");
    Ok(Json(DeleteAccountResponse { ok: true }))
}

/// Holds the user's profile and listings until the deletion commits. A new
/// reservation or order on one of the listings waits on these locks (its
/// foreign-key check needs a key-share lock); afterwards it fails on a
/// deleted listing. A purchase already past its availability check when the
/// deletion starts can still land on a kept listing; admins refund it.
async fn lock_account(tx: &mut Transaction<'_, Postgres>, user_id: Uuid) -> Result<(), AppError> {
    sqlx::query("SELECT id FROM profiles WHERE id = $1 FOR UPDATE")
        .bind(user_id)
        .fetch_optional(&mut **tx)
        .await?;
    sqlx::query("SELECT id FROM listings WHERE seller_id = $1 FOR UPDATE")
        .bind(user_id)
        .fetch_all(&mut **tx)
        .await?;
    Ok(())
}

/// True while money is in flight for the user as buyer or seller: a payment
/// is pending, escrow is held or disputed, or a buyer holds a reservation.
pub async fn has_open_orders(
    tx: &mut Transaction<'_, Postgres>,
    user_id: Uuid,
) -> Result<bool, AppError> {
    let open: bool = sqlx::query_scalar(
        "SELECT EXISTS ( \
             SELECT 1 FROM transactions t \
             LEFT JOIN escrow_transactions e ON e.transaction_id = t.id \
             WHERE (t.buyer_id = $1 OR t.seller_id = $1) \
               AND (t.status IN ('pending', 'pending_payment', 'held', 'disputed') \
                    OR e.status IN ('held', 'disputed')) \
         ) OR EXISTS ( \
             SELECT 1 FROM listing_reservations r \
             JOIN listings l ON l.id = r.listing_id \
             WHERE r.reserved_until > now() AND (r.buyer_id = $1 OR l.seller_id = $1) \
         )",
    )
    .bind(user_id)
    .fetch_one(&mut **tx)
    .await?;
    Ok(open)
}

async fn delete_personal_rows(
    tx: &mut Transaction<'_, Postgres>,
    user_id: Uuid,
) -> Result<(), AppError> {
    const STATEMENTS: [&str; 11] = [
        // Payer phone numbers, keyed by the user's payment references.
        "DELETE FROM payment_payers WHERE payment_reference IN ( \
             SELECT payment_reference FROM transactions WHERE buyer_id = $1 \
             UNION SELECT payment_reference FROM boost_payments WHERE user_id = $1 \
             UNION SELECT payment_reference FROM donations WHERE user_id = $1 \
             UNION SELECT fapshi_reference FROM subscriptions WHERE user_id = $1 \
             UNION SELECT trans_id FROM upgrade_codes WHERE user_id = $1 AND trans_id IS NOT NULL)",
        "DELETE FROM listing_reservations WHERE buyer_id = $1 \
             OR listing_id IN (SELECT id FROM listings WHERE seller_id = $1)",
        "DELETE FROM messages WHERE sender_id = $1 OR receiver_id = $1",
        "DELETE FROM favorites WHERE user_id = $1",
        "DELETE FROM wishlists WHERE user_id = $1",
        "DELETE FROM notifications WHERE user_id = $1",
        "DELETE FROM upgrade_codes WHERE user_id = $1",
        "DELETE FROM admin_users WHERE user_id = $1",
        // Star ratings stay so other sellers keep their reputation.
        "UPDATE reviews SET comment = NULL WHERE reviewer_id = $1 AND comment IS NOT NULL",
        "UPDATE feedback SET user_id = NULL WHERE user_id = $1",
        "DELETE FROM profiles_private WHERE id = $1",
    ];
    for sql in STATEMENTS {
        sqlx::query(sql).bind(user_id).execute(&mut **tx).await?;
    }
    Ok(())
}

/// Deletes listings nothing else points at; listings tied to an order,
/// review or boost payment are kept for those records, stripped of photos,
/// description and location, and taken off the market.
async fn close_listings(tx: &mut Transaction<'_, Postgres>, user_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "DELETE FROM listings l WHERE l.seller_id = $1 \
           AND NOT EXISTS (SELECT 1 FROM transactions t WHERE t.listing_id = l.id) \
           AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.listing_id = l.id) \
           AND NOT EXISTS (SELECT 1 FROM boost_payments b WHERE b.listing_id = l.id)",
    )
    .bind(user_id)
    .execute(&mut **tx)
    .await?;
    sqlx::query(
        "UPDATE listings SET \
             status = CASE WHEN status = 'sold' THEN 'sold' ELSE 'removed' END, \
             image_url = NULL, image_urls = '{}', description = NULL, \
             is_boosted = false, boost_expires_at = NULL, \
             latitude = NULL, longitude = NULL, \
             meetup_spot = NULL, meetup_latitude = NULL, meetup_longitude = NULL \
         WHERE seller_id = $1",
    )
    .bind(user_id)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn anonymise_profile(
    tx: &mut Transaction<'_, Postgres>,
    user_id: Uuid,
) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE profiles SET \
             full_name = $2, email = NULL, locality = NULL, whatsapp_number = NULL, \
             avatar_url = NULL, fcm_token = NULL, school_id = NULL, tier = 'free', \
             age_declaration = NULL, age_declared_at = NULL, date_of_birth = NULL, \
             id_verification_status = CASE WHEN id_verification_status = 'verified' \
                                           THEN 'verified' ELSE 'unverified' END, \
             id_type = NULL, guardian_phone = NULL, id_document_paths = '{}', \
             id_submitted_at = NULL, id_rejection_reason = NULL \
         WHERE id = $1",
    )
    .bind(user_id)
    .bind(DELETED_USER_NAME)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// Scrubs the login so the account can never be signed into again. The row
/// stays because orders and reviews reference it. The ban is 100 years, not
/// `infinity`, which Supabase Auth cannot parse.
async fn close_login(tx: &mut Transaction<'_, Postgres>, user_id: Uuid) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE auth.users SET \
             email = NULL, phone = NULL, encrypted_password = '', \
             raw_user_meta_data = '{}'::jsonb, \
             banned_until = now() + interval '100 years', deleted_at = now() \
         WHERE id = $1",
    )
    .bind(user_id)
    .execute(&mut **tx)
    .await?;
    for table in ["identities", "sessions", "mfa_factors", "one_time_tokens"] {
        sqlx::query(&format!("DELETE FROM auth.{table} WHERE user_id = $1"))
            .bind(user_id)
            .execute(&mut **tx)
            .await?;
    }
    // refresh_tokens.user_id is varchar in Supabase Auth.
    sqlx::query("DELETE FROM auth.refresh_tokens WHERE user_id = $1::text")
        .bind(user_id.to_string())
        .execute(&mut **tx)
        .await?;
    Ok(())
}
