use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("HTTP client error: {0}")]
    Reqwest(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Fapshi error: {0}")]
    Fapshi(String),

    #[error("Bad Request: {0}")]
    BadRequest(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Auth service error: {0}")]
    AuthService(String),

    #[error("Internal server error: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match &self {
            AppError::Database(e) => {
                tracing::error!("Database error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error".to_string())
            }
            AppError::Reqwest(e) => {
                tracing::error!("Reqwest error: {:?}", e);
                (StatusCode::BAD_GATEWAY, "Gateway error".to_string())
            }
            AppError::Json(e) => {
                tracing::error!("JSON serialization error: {:?}", e);
                (StatusCode::BAD_REQUEST, "Malformed JSON request".to_string())
            }
            AppError::Unauthorized(msg) => {
                tracing::warn!("Unauthorized access: {}", msg);
                (StatusCode::UNAUTHORIZED, msg.clone())
            }
            AppError::Fapshi(msg) => {
                tracing::error!("Fapshi integration error: {}", msg);
                (StatusCode::BAD_GATEWAY, msg.clone())
            }
            AppError::BadRequest(msg) => {
                tracing::warn!("Bad request: {}", msg);
                (StatusCode::BAD_REQUEST, msg.clone())
            }
            AppError::NotFound(msg) => {
                tracing::warn!("Not found: {}", msg);
                (StatusCode::NOT_FOUND, msg.clone())
            }
            AppError::Conflict(msg) => {
                tracing::warn!("Conflict: {}", msg);
                (StatusCode::CONFLICT, msg.clone())
            }
            AppError::AuthService(msg) => {
                tracing::error!("Auth service error: {}", msg);
                (StatusCode::BAD_GATEWAY, "Authentication service unavailable".to_string())
            }
            AppError::Internal(msg) => {
                tracing::error!("Internal error: {}", msg);
                (StatusCode::INTERNAL_SERVER_ERROR, msg.clone())
            }
        };

        let body = Json(json!({
            "error": error_message,
        }));

        (status, body).into_response()
    }
}
