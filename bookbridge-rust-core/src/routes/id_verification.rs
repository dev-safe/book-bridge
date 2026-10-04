//! Admin review of ID verification submissions (#34, #36).
//!
//! An admin looks at the uploaded photos (signed URLs created by the app),
//! then approves or rejects. Either way the photos are deleted from Storage
//! and only the outcome is kept; the decision is recorded in `admin_actions`.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::error::AppError;
use crate::routes::admin::{mask_phone, validate_note};
use crate::routes::escrow::{record_user_admin_action, AdminDecision};
use crate::user_auth::{bearer_token, AdminUser};
use crate::AppState;

pub const ID_DOCUMENTS_BUCKET: &str = "id-documents";
const LIST_LIMIT: i64 = 200;

#[derive(Deserialize)]
pub struct ReviewRequest {
    pub note: String,
}

#[derive(Serialize)]
pub struct ReviewResponse {
    pub ok: bool,
    pub status: &'static str,
}

#[derive(Serialize)]
pub struct IdVerificationSummary {
    pub user_id: Uuid,
    pub full_name: Option<String>,
    pub date_of_birth: Option<NaiveDate>,
    pub age: Option<i32>,
    pub id_type: Option<String>,
    /// Masked guardian number, for users aged 10-14.
    pub guardian_phone_hint: Option<String>,
    /// Object paths in the `id-documents` bucket.
    pub document_paths: Vec<String>,
    pub submitted_at: Option<DateTime<Utc>>,
}

#[derive(Serialize)]
pub struct IdVerificationList {
    pub submissions: Vec<IdVerificationSummary>,
}

#[derive(Clone, Copy)]
enum Review {
    Approve,
    Reject,
}

impl Review {
    fn status(self) -> &'static str {
        match self {
            Review::Approve => "verified",
            Review::Reject => "rejected",
        }
    }

    fn action(self) -> &'static str {
        match self {
            Review::Approve => "approve_id",
            Review::Reject => "reject_id",
        }
    }
}

pub fn id_verification_routes() -> Router<AppState> {
    Router::new()
        .route("/admin/id-verifications", get(list_handler))
        .route(
            "/admin/id-verifications/:user_id/approve",
            post(approve_handler),
        )
        .route(
            "/admin/id-verifications/:user_id/reject",
            post(reject_handler),
        )
}

pub async fn list_handler(
    State(state): State<AppState>,
    _admin: AdminUser,
) -> Result<Json<IdVerificationList>, AppError> {
    let rows = sqlx::query(
        "SELECT id, full_name, date_of_birth, id_type, guardian_phone, id_document_paths, \
                id_submitted_at, date_part('year', age(current_date, date_of_birth))::int AS age \
         FROM profiles \
         WHERE id_verification_status = 'pending' \
         ORDER BY id_submitted_at ASC NULLS FIRST \
         LIMIT $1",
    )
    .bind(LIST_LIMIT)
    .fetch_all(&state.pool)
    .await?;

    let submissions = rows
        .into_iter()
        .map(|row| {
            let guardian: Option<String> = row.get("guardian_phone");
            IdVerificationSummary {
                user_id: row.get("id"),
                full_name: row.get("full_name"),
                date_of_birth: row.get("date_of_birth"),
                age: row.get("age"),
                id_type: row.get("id_type"),
                guardian_phone_hint: guardian.as_deref().map(mask_phone),
                document_paths: row.get("id_document_paths"),
                submitted_at: row.get("id_submitted_at"),
            }
        })
        .collect();

    Ok(Json(IdVerificationList { submissions }))
}

pub async fn approve_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    headers: HeaderMap,
    Path(user_id): Path<Uuid>,
    Json(request): Json<ReviewRequest>,
) -> Result<Json<ReviewResponse>, AppError> {
    review(
        &state,
        admin_id,
        &headers,
        user_id,
        &request.note,
        Review::Approve,
    )
    .await
}

pub async fn reject_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    headers: HeaderMap,
    Path(user_id): Path<Uuid>,
    Json(request): Json<ReviewRequest>,
) -> Result<Json<ReviewResponse>, AppError> {
    review(
        &state,
        admin_id,
        &headers,
        user_id,
        &request.note,
        Review::Reject,
    )
    .await
}

/// Locks the profile, deletes the photos, records the outcome and commits.
/// If the Storage delete fails nothing is written, so the admin can retry.
async fn review(
    state: &AppState,
    admin_id: Uuid,
    headers: &HeaderMap,
    user_id: Uuid,
    raw_note: &str,
    review: Review,
) -> Result<Json<ReviewResponse>, AppError> {
    let note = validate_note(raw_note)?;
    let token = bearer_token(headers)?;

    let mut tx = state.pool.begin().await?;
    let row = sqlx::query(
        "SELECT id_verification_status, id_document_paths FROM profiles WHERE id = $1 FOR UPDATE",
    )
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| AppError::NotFound(format!("Profile {user_id} not found")))?;

    let status: String = row.get("id_verification_status");
    if status != "pending" {
        return Err(AppError::Conflict(format!(
            "This submission is '{status}', not pending"
        )));
    }
    let paths: Vec<String> = row.get("id_document_paths");

    state
        .supabase_auth
        .delete_storage_objects(token, ID_DOCUMENTS_BUCKET, &paths)
        .await?;

    let rejection_reason = match review {
        Review::Reject => Some(note.as_str()),
        Review::Approve => None,
    };
    sqlx::query(
        "UPDATE profiles SET id_verification_status = $2, id_document_paths = '{}', \
                id_reviewed_by = $3, id_reviewed_at = now(), id_rejection_reason = $4 \
         WHERE id = $1",
    )
    .bind(user_id)
    .bind(review.status())
    .bind(admin_id)
    .bind(rejection_reason)
    .execute(&mut *tx)
    .await?;

    let decision = AdminDecision {
        admin_id,
        action: review.action(),
        note: &note,
    };
    record_user_admin_action(&mut tx, &decision, user_id).await?;
    tx.commit().await?;

    tracing::info!(%admin_id, %user_id, action = review.action(), "ID verification reviewed");
    Ok(Json(ReviewResponse {
        ok: true,
        status: review.status(),
    }))
}
