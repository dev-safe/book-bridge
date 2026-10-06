//! Admin review of user reports (Google Play user-generated content policy).
//!
//! Users file reports from the app straight into `content_reports` (RLS
//! insert only). Admins list open reports here and either dismiss them or
//! take the reported listing off the market. Each decision is recorded in
//! `admin_actions` and closes every open report about the same listing.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgConnection, Row};
use uuid::Uuid;

use crate::error::AppError;
use crate::routes::admin::validate_note;
use crate::user_auth::AdminUser;
use crate::AppState;

const LIST_LIMIT: i64 = 200;

#[derive(Deserialize)]
pub struct ReportDecisionRequest {
    pub note: String,
}

#[derive(Serialize)]
pub struct ReportDecisionResponse {
    pub ok: bool,
    pub status: &'static str,
    /// Open reports closed by this decision, including this one.
    pub closed_reports: i64,
}

#[derive(Serialize)]
pub struct ReportSummary {
    pub id: Uuid,
    pub reason: String,
    pub details: Option<String>,
    pub created_at: DateTime<Utc>,
    pub reporter_name: Option<String>,
    pub listing_id: Option<Uuid>,
    pub listing_title: Option<String>,
    pub listing_status: Option<String>,
    pub reported_user_id: Option<Uuid>,
    pub reported_user_name: Option<String>,
}

#[derive(Serialize)]
pub struct ReportList {
    pub reports: Vec<ReportSummary>,
}

pub fn report_routes() -> Router<AppState> {
    Router::new()
        .route("/admin/reports", get(list_handler))
        .route("/admin/reports/:report_id/dismiss", post(dismiss_handler))
        .route(
            "/admin/reports/:report_id/remove-listing",
            post(remove_listing_handler),
        )
}

pub async fn list_handler(
    State(state): State<AppState>,
    _admin: AdminUser,
) -> Result<Json<ReportList>, AppError> {
    let rows = sqlx::query(
        "SELECT r.id, r.reason, r.details, r.created_at, r.listing_id, r.reported_user_id, \
                rp.full_name AS reporter_name, l.title AS listing_title, \
                l.status AS listing_status, \
                COALESCE(ru.full_name, ls.full_name) AS reported_user_name, \
                COALESCE(r.reported_user_id, l.seller_id) AS target_user_id \
         FROM content_reports r \
         LEFT JOIN profiles rp ON rp.id = r.reporter_id \
         LEFT JOIN listings l ON l.id = r.listing_id \
         LEFT JOIN profiles ru ON ru.id = r.reported_user_id \
         LEFT JOIN profiles ls ON ls.id = l.seller_id \
         WHERE r.status = 'open' \
         ORDER BY r.created_at ASC \
         LIMIT $1",
    )
    .bind(LIST_LIMIT)
    .fetch_all(&state.pool)
    .await?;

    let reports = rows
        .into_iter()
        .map(|row| ReportSummary {
            id: row.get("id"),
            reason: row.get("reason"),
            details: row.get("details"),
            created_at: row.get("created_at"),
            reporter_name: row.get("reporter_name"),
            listing_id: row.get("listing_id"),
            listing_title: row.get("listing_title"),
            listing_status: row.get("listing_status"),
            reported_user_id: row.get("target_user_id"),
            reported_user_name: row.get("reported_user_name"),
        })
        .collect();

    Ok(Json(ReportList { reports }))
}

pub async fn dismiss_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(report_id): Path<Uuid>,
    Json(request): Json<ReportDecisionRequest>,
) -> Result<Json<ReportDecisionResponse>, AppError> {
    let note = validate_note(&request.note)?;
    let mut tx = state.pool.begin().await?;
    lock_open_report(&mut tx, report_id).await?;

    let closed = close_reports(&mut tx, "id = $1", report_id, "dismissed", admin_id).await?;
    record_report_action(&mut tx, admin_id, "dismiss_report", report_id, &note).await?;
    tx.commit().await?;

    tracing::info!(%admin_id, %report_id, "Report dismissed");
    Ok(Json(ReportDecisionResponse {
        ok: true,
        status: "dismissed",
        closed_reports: closed,
    }))
}

/// Takes the reported listing off the market (status `removed`; a sold
/// listing stays `sold`) and closes every open report about it.
pub async fn remove_listing_handler(
    State(state): State<AppState>,
    AdminUser(admin_id): AdminUser,
    Path(report_id): Path<Uuid>,
    Json(request): Json<ReportDecisionRequest>,
) -> Result<Json<ReportDecisionResponse>, AppError> {
    let note = validate_note(&request.note)?;
    let mut tx = state.pool.begin().await?;
    let listing_id = lock_open_report(&mut tx, report_id)
        .await?
        .ok_or_else(|| AppError::BadRequest("This report is not about a listing".to_string()))?;

    let updated = sqlx::query(
        "UPDATE listings SET \
             status = CASE WHEN status = 'sold' THEN 'sold' ELSE 'removed' END, \
             is_boosted = false, boost_expires_at = NULL \
         WHERE id = $1",
    )
    .bind(listing_id)
    .execute(&mut *tx)
    .await?;
    if updated.rows_affected() == 0 {
        return Err(AppError::NotFound(format!(
            "Listing {listing_id} not found"
        )));
    }

    let closed =
        close_reports(&mut tx, "listing_id = $1", listing_id, "actioned", admin_id).await?;
    record_report_action(
        &mut tx,
        admin_id,
        "remove_reported_listing",
        report_id,
        &note,
    )
    .await?;
    tx.commit().await?;

    tracing::info!(%admin_id, %report_id, %listing_id, "Reported listing removed");
    Ok(Json(ReportDecisionResponse {
        ok: true,
        status: "actioned",
        closed_reports: closed,
    }))
}

/// Locks an open report and returns its listing id, if any.
async fn lock_open_report(
    conn: &mut PgConnection,
    report_id: Uuid,
) -> Result<Option<Uuid>, AppError> {
    let row =
        sqlx::query("SELECT status, listing_id FROM content_reports WHERE id = $1 FOR UPDATE")
            .bind(report_id)
            .fetch_optional(&mut *conn)
            .await?
            .ok_or_else(|| AppError::NotFound(format!("Report {report_id} not found")))?;
    let status: String = row.get("status");
    if status != "open" {
        return Err(AppError::Conflict(format!(
            "This report is '{status}', not open"
        )));
    }
    Ok(row.get("listing_id"))
}

async fn close_reports(
    conn: &mut PgConnection,
    filter: &'static str,
    id: Uuid,
    status: &'static str,
    admin_id: Uuid,
) -> Result<i64, AppError> {
    let sql = format!(
        "UPDATE content_reports SET status = $2, reviewed_by = $3, reviewed_at = now() \
         WHERE status = 'open' AND {filter}"
    );
    let result = sqlx::query(&sql)
        .bind(id)
        .bind(status)
        .bind(admin_id)
        .execute(&mut *conn)
        .await?;
    Ok(result.rows_affected() as i64)
}

async fn record_report_action(
    conn: &mut PgConnection,
    admin_id: Uuid,
    action: &'static str,
    report_id: Uuid,
    note: &str,
) -> Result<(), AppError> {
    sqlx::query(
        "INSERT INTO admin_actions (admin_id, action, report_id, note) VALUES ($1, $2, $3, $4)",
    )
    .bind(admin_id)
    .bind(action)
    .bind(report_id)
    .bind(note)
    .execute(&mut *conn)
    .await?;
    Ok(())
}
