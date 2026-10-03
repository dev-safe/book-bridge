//! Authentication of app users (buyers/sellers), as opposed to the
//! `X-Internal-Secret` check in `auth.rs` used by cron callers.
//!
//! Every request asks Supabase Auth (`GET /auth/v1/user`) who the access
//! token belongs to. This is slower than verifying the JWT locally, but it
//! also rejects sessions that were signed out, and there is no crypto code
//! here to get wrong. The endpoints using it are rare, money-moving actions.

use axum::{
    async_trait,
    extract::{FromRef, FromRequestParts},
    http::{header::AUTHORIZATION, request::Parts, HeaderMap, StatusCode},
};
use serde::Deserialize;
use std::time::Duration;
use uuid::Uuid;

use crate::error::AppError;
use crate::AppState;

const AUTH_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone)]
pub struct SupabaseAuth {
    http: reqwest::Client,
    base_url: String,
    anon_key: String,
}

#[derive(Deserialize)]
struct AuthUserResponse {
    id: Uuid,
}

impl SupabaseAuth {
    pub fn new(base_url: impl Into<String>, anon_key: impl Into<String>) -> Self {
        let http = reqwest::Client::builder()
            .timeout(AUTH_TIMEOUT)
            .build()
            .expect("reqwest client with a timeout always builds");
        Self {
            http,
            base_url: base_url.into().trim_end_matches('/').to_string(),
            anon_key: anon_key.into(),
        }
    }

    /// Returns the id of the user the access token belongs to.
    pub async fn user_id(&self, access_token: &str) -> Result<Uuid, AppError> {
        let response = self
            .http
            .get(format!("{}/auth/v1/user", self.base_url))
            .header("apikey", &self.anon_key)
            .bearer_auth(access_token)
            .send()
            .await
            .map_err(|e| AppError::AuthService(format!("request failed: {e}")))?;

        match response.status() {
            s if s.is_success() => response
                .json::<AuthUserResponse>()
                .await
                .map(|user| user.id)
                .map_err(|e| AppError::AuthService(format!("unexpected response: {e}"))),
            StatusCode::UNAUTHORIZED | StatusCode::FORBIDDEN => Err(AppError::Unauthorized(
                "Invalid or expired session".to_string(),
            )),
            s => Err(AppError::AuthService(format!("status {s}"))),
        }
    }
}

/// Extracts the token from an `Authorization: Bearer <token>` header.
pub fn bearer_token(headers: &HeaderMap) -> Result<&str, AppError> {
    let missing = || AppError::Unauthorized("Missing bearer token".to_string());
    let value = headers
        .get(AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .ok_or_else(missing)?;
    let (scheme, token) = value.split_once(' ').ok_or_else(missing)?;
    let token = token.trim();
    if !scheme.eq_ignore_ascii_case("bearer") || token.is_empty() {
        return Err(missing());
    }
    Ok(token)
}

/// The signed-in app user making the request, verified with Supabase Auth.
pub struct AuthenticatedUser(pub Uuid);

#[async_trait]
impl<S> FromRequestParts<S> for AuthenticatedUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = bearer_token(&parts.headers)?;
        let state = AppState::from_ref(state);
        state
            .supabase_auth
            .user_id(token)
            .await
            .map(AuthenticatedUser)
    }
}

/// A signed-in user listed in `admin_users`. Others get 403.
pub struct AdminUser(pub Uuid);

#[async_trait]
impl<S> FromRequestParts<S> for AdminUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let AuthenticatedUser(user_id) = AuthenticatedUser::from_request_parts(parts, state).await?;
        let state = AppState::from_ref(state);
        let is_admin: bool =
            sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM admin_users WHERE user_id = $1)")
                .bind(user_id)
                .fetch_one(&state.pool)
                .await?;
        if is_admin {
            Ok(AdminUser(user_id))
        } else {
            Err(AppError::Forbidden("Admin access required".to_string()))
        }
    }
}
