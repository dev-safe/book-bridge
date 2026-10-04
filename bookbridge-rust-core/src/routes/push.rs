//! Delivers pending rows of `public.notifications` as FCM push messages.
//!
//! Called by the database (statement trigger on insert, plus a two-minute
//! retry cron) through `/internal/push/dispatch`.

use axum::{extract::State, response::IntoResponse, Json};
use serde::Serialize;
use serde_json::Value;
use sqlx::Row;
use uuid::Uuid;

use crate::error::AppError;
use crate::push::{FcmClient, PushMessage, SendError};
use crate::AppState;

/// Attempts before a failing row is closed with its last error.
pub const MAX_PUSH_ATTEMPTS: i32 = 5;
/// Rows older than this are closed as 'expired' instead of being pushed late.
pub const PUSH_EXPIRY_HOURS: i32 = 24;
const BATCH_SIZE: i64 = 50;
const MAX_BATCHES_PER_RUN: usize = 10;

#[derive(Serialize, Default, Debug)]
pub struct DispatchPushResponse {
    /// False when another dispatch was already running; nothing was done.
    pub ran: bool,
    pub configured: bool,
    pub expired: u64,
    pub sent: usize,
    pub no_token: usize,
    pub invalid_token: usize,
    pub failed: usize,
}

pub async fn dispatch_push_handler(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    // One run at a time keeps a burst of trigger calls from holding many
    // pooled connections. The running dispatch drains rows added meanwhile.
    let Ok(_guard) = state.push.dispatch_lock.try_lock() else {
        return Ok(Json(DispatchPushResponse::default()));
    };

    let mut resp = DispatchPushResponse {
        ran: true,
        configured: state.push.client.is_some(),
        ..Default::default()
    };

    resp.expired = sqlx::query(
        "UPDATE public.notifications
            SET push_sent_at = now(), push_error = 'expired'
          WHERE push_sent_at IS NULL
            AND created_at < now() - make_interval(hours => $1)",
    )
    .bind(PUSH_EXPIRY_HOURS)
    .execute(&state.pool)
    .await?
    .rows_affected();

    let Some(fcm) = state.push.client.as_deref() else {
        tracing::warn!(
            "Push dispatch called but FCM_SERVICE_ACCOUNT_JSON is not set; rows left pending"
        );
        return Ok(Json(resp));
    };

    let mut seen: Vec<Uuid> = Vec::new();
    for _ in 0..MAX_BATCHES_PER_RUN {
        let handled = dispatch_batch(&state, fcm, &mut seen, &mut resp).await?;
        if handled < BATCH_SIZE as usize {
            break;
        }
    }

    tracing::info!(
        sent = resp.sent,
        no_token = resp.no_token,
        invalid_token = resp.invalid_token,
        failed = resp.failed,
        expired = resp.expired,
        "Push dispatch finished"
    );
    Ok(Json(resp))
}

async fn dispatch_batch(
    state: &AppState,
    fcm: &FcmClient,
    seen: &mut Vec<Uuid>,
    resp: &mut DispatchPushResponse,
) -> Result<usize, AppError> {
    let mut tx = state.pool.begin().await?;

    // Rows already tried in this run are skipped so a failing row is retried
    // by the next run, not hammered in a loop.
    let rows = sqlx::query(
        "SELECT n.id, n.user_id, n.type, n.title, n.body, n.data,
                pp.fcm_token
           FROM public.notifications n
           LEFT JOIN public.profiles_private pp ON pp.id = n.user_id
          WHERE n.push_sent_at IS NULL
            AND n.push_attempts < $1
            AND NOT (n.id = ANY($2))
          ORDER BY n.created_at
          LIMIT $3
          FOR UPDATE OF n SKIP LOCKED",
    )
    .bind(MAX_PUSH_ATTEMPTS)
    .bind(&seen[..])
    .bind(BATCH_SIZE)
    .fetch_all(&mut *tx)
    .await?;

    for row in &rows {
        let id: Uuid = row.try_get("id")?;
        let user_id: Uuid = row.try_get("user_id")?;
        let kind: String = row.try_get("type")?;
        let title: String = row.try_get("title")?;
        let body: String = row.try_get("body")?;
        let data: Option<Value> = row.try_get("data")?;
        let token: Option<String> = row.try_get("fcm_token")?;
        seen.push(id);

        let token = match token {
            Some(t) if !t.trim().is_empty() => t,
            _ => {
                close_row(&mut tx, id, Some("no_token")).await?;
                resp.no_token += 1;
                continue;
            }
        };

        let msg = PushMessage {
            token: &token,
            title: &title,
            body: &body,
            kind: &kind,
            data: data.as_ref(),
        };
        match fcm.send(&msg).await {
            Ok(_) => {
                close_row(&mut tx, id, None).await?;
                resp.sent += 1;
            }
            Err(SendError::InvalidToken(detail)) => {
                tracing::info!(notification_id = %id, "FCM token rejected; clearing it");
                clear_token(&mut tx, user_id, &token).await?;
                close_row(&mut tx, id, Some(&format!("invalid_token: {detail}"))).await?;
                resp.invalid_token += 1;
            }
            Err(SendError::Failed(detail)) => {
                tracing::warn!(notification_id = %id, error = %detail, "Push send failed");
                sqlx::query(
                    "UPDATE public.notifications
                        SET push_attempts = push_attempts + 1,
                            push_error = $2,
                            push_sent_at = CASE WHEN push_attempts + 1 >= $3 THEN now() END
                      WHERE id = $1",
                )
                .bind(id)
                .bind(&detail)
                .bind(MAX_PUSH_ATTEMPTS)
                .execute(&mut *tx)
                .await?;
                resp.failed += 1;
            }
        }
    }

    tx.commit().await?;
    Ok(rows.len())
}

async fn close_row(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    id: Uuid,
    error: Option<&str>,
) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE public.notifications SET push_sent_at = now(), push_error = $2 WHERE id = $1",
    )
    .bind(id)
    .bind(error)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// The profiles -> profiles_private sync trigger ignores NULLs, so a dead
/// token has to be cleared in both tables. Only the rejected token is
/// cleared, in case the device registered a new one meanwhile.
async fn clear_token(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
    token: &str,
) -> Result<(), AppError> {
    sqlx::query(
        "UPDATE public.profiles_private SET fcm_token = NULL WHERE id = $1 AND fcm_token = $2",
    )
    .bind(user_id)
    .bind(token)
    .execute(&mut **tx)
    .await?;
    sqlx::query("UPDATE public.profiles SET fcm_token = NULL WHERE id = $1 AND fcm_token = $2")
        .bind(user_id)
        .bind(token)
        .execute(&mut **tx)
        .await?;
    Ok(())
}
