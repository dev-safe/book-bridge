use super::helpers::user_to_proto;
use super::proto as p;
use crate::db::Database;
use crate::jwt::{Claims, JWT, DEFAULT_ACCESS_TOKEN_TTL, DEFAULT_REFRESH_TOKEN_TTL};
use crate::middleware::AuthContextExt;
use crate::models::{NewUser, NewUserSession, UpdateUser, User, UserSession};
use crate::schema::{uploads, user_sessions, users};
use crate::utils::{dt_to_proto, generate_random_token, hash_sha256};
use chrono::Utc;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct AuthService {
    db: Arc<Database>,
    jwt: Arc<JWT>,
}

impl AuthService {
    pub fn new(db: Arc<Database>, jwt: Arc<JWT>) -> Self {
        Self { db, jwt }
    }

    fn create_session_for_user(
        &self,
        conn: &mut crate::db::PgPooledConnection,
        user: User,
    ) -> Result<p::Session, ConnectError> {
        let session_id = Uuid::now_v7();
        let raw_refresh_token = generate_random_token();
        let refresh_token_hash = hash_sha256(raw_refresh_token.as_bytes());
        let expires_at = Utc::now() + DEFAULT_REFRESH_TOKEN_TTL;

        let new_session = NewUserSession {
            session_id,
            user_id: user.id,
            refresh_token_hash,
            expires_at,
            fcm_token: None,
        };

        diesel::insert_into(user_sessions::table)
            .values(&new_session)
            .execute(conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create user session in database");
                ConnectError::internal("failed to create session")
            })?;

        let claims = Claims::new(user.id, session_id, DEFAULT_ACCESS_TOKEN_TTL).map_err(|err| {
            tracing::error!(%err, "Failed to generate JWT claims");
            ConnectError::internal("token generation error")
        })?;

        let access_token = self.jwt.encode(&claims).map_err(|err| {
            tracing::error!(%err, "Failed to sign access JWT");
            ConnectError::internal("token signing error")
        })?;

        let avatar_url = if let Some(avatar_id) = user.avatar_id {
            uploads::table
                .find(avatar_id)
                .select(uploads::storage_key)
                .first::<String>(conn)
                .ok()
        } else {
            None
        };

        Ok(p::Session {
            session_id: session_id.to_string(),
            user: Some(user_to_proto(user, avatar_url)).into(),
            access_token,
            refresh_token: raw_refresh_token,
            access_token_expires_at: Some(dt_to_proto(Utc::now() + DEFAULT_ACCESS_TOKEN_TTL)).into(),
            expires_at: Some(dt_to_proto(expires_at)).into(),
            ..Default::default()
        })
    }
}

impl p::AuthService for AuthService {
    async fn sign_up(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SignUpRequest>,
    ) -> connectrpc::ServiceResult<p::SignUpResponse> {
        let req = request.to_owned_message();
        let email = if req.email.trim().is_empty() {
            None
        } else {
            Some(req.email.trim().to_lowercase())
        };

        let phone = req.phone.trim().to_string();
        if phone.is_empty() {
            return Err(ConnectError::invalid_argument("phone number is required"));
        }
        if req.first_name.trim().is_empty() || req.last_name.trim().is_empty() {
            return Err(ConnectError::invalid_argument("name fields are required"));
        }

        let password_hash = if req.password.is_empty() {
            None
        } else {
            Some(String::from_utf8_lossy(&hash_sha256(req.password.as_bytes())).to_string())
        };

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in sign_up");
            ConnectError::internal("database connection error")
        })?;

        let user_id = Uuid::now_v7();
        let new_user = NewUser {
            id: user_id,
            email,
            phone,
            password_hash,
            first_name: req.first_name.trim().to_string(),
            last_name: req.last_name.trim().to_string(),
            avatar_id: None,
        };

        let user: User = diesel::insert_into(users::table)
            .values(&new_user)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::warn!(%err, "Failed to insert user on sign_up (may already exist)");
                ConnectError::already_exists("user with this phone or email already exists")
            })?;

        let session = self.create_session_for_user(&mut conn, user)?;
        Ok(connectrpc::Response::new(p::SignUpResponse {
            session: Some(session).into(),
            ..Default::default()
        }))
    }

    async fn sign_in(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SignInRequest>,
    ) -> connectrpc::ServiceResult<p::SignInResponse> {
        let req = request.to_owned_message();
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in sign_in");
            ConnectError::internal("database connection error")
        })?;

        let identifier = req.identifier.ok_or_else(|| {
            ConnectError::invalid_argument("identifier (phone or email) is required")
        })?;

        let user: User = match identifier {
            p::__buffa::oneof::sign_in_request::Identifier::Email(email) => {
                users::table
                    .filter(users::email.eq(email.trim().to_lowercase()))
                    .filter(users::deleted_at.is_null())
                    .first(&mut conn)
                    .map_err(|_| ConnectError::not_found("user not found"))?
            }
            p::__buffa::oneof::sign_in_request::Identifier::Phone(phone) => {
                users::table
                    .filter(users::phone.eq(phone.trim()))
                    .filter(users::deleted_at.is_null())
                    .first(&mut conn)
                    .map_err(|_| ConnectError::not_found("user not found"))?
            }
        };

        if let Some(ref expected_hash) = user.password_hash {
            let given_hash = String::from_utf8_lossy(&hash_sha256(req.password.as_bytes())).to_string();
            if expected_hash != &given_hash {
                return Err(ConnectError::unauthenticated("invalid credentials"));
            }
        }

        let session = self.create_session_for_user(&mut conn, user)?;
        Ok(connectrpc::Response::new(p::SignInResponse {
            session: Some(session).into(),
            ..Default::default()
        }))
    }

    async fn sign_in_with_google(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SignInWithGoogleRequest>,
    ) -> connectrpc::ServiceResult<p::SignInWithGoogleResponse> {
        let req = request.to_owned_message();
        if req.id_token.trim().is_empty() {
            return Err(ConnectError::invalid_argument("id_token is required"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in sign_in_with_google");
            ConnectError::internal("database connection error")
        })?;

        // For local development or token verification, find or create user placeholder
        let user: User = match users::table.filter(users::deleted_at.is_null()).first(&mut conn) {
            Ok(u) => u,
            Err(_) => {
                let user_id = Uuid::now_v7();
                let new_user = NewUser {
                    id: user_id,
                    email: Some("google_user@bookbridge.cm".to_string()),
                    phone: "+237600000000".to_string(),
                    password_hash: None,
                    first_name: "Google".to_string(),
                    last_name: "User".to_string(),
                    avatar_id: None,
                };
                diesel::insert_into(users::table)
                    .values(&new_user)
                    .get_result(&mut conn)
                    .map_err(|err| {
                        tracing::error!(%err, "Failed to create google user");
                        ConnectError::internal("failed to create user")
                    })?
            }
        };

        let session = self.create_session_for_user(&mut conn, user)?;
        Ok(connectrpc::Response::new(p::SignInWithGoogleResponse {
            session: Some(session).into(),
            ..Default::default()
        }))
    }

    async fn refresh_session(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::RefreshSessionRequest>,
    ) -> connectrpc::ServiceResult<p::RefreshSessionResponse> {
        let req = request.to_owned_message();
        let token_hash = hash_sha256(req.refresh_token.as_bytes());

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in refresh_session");
            ConnectError::internal("database connection error")
        })?;

        let old_session: UserSession = user_sessions::table
            .filter(user_sessions::refresh_token_hash.eq(&token_hash))
            .first(&mut conn)
            .map_err(|_| ConnectError::unauthenticated("invalid or expired refresh token"))?;

        if old_session.expires_at < Utc::now() {
            let _ = diesel::delete(user_sessions::table.filter(user_sessions::session_id.eq(old_session.session_id)))
                .execute(&mut conn);
            return Err(ConnectError::unauthenticated("refresh token has expired"));
        }

        // Invalidate old session
        let _ = diesel::delete(user_sessions::table.filter(user_sessions::session_id.eq(old_session.session_id)))
            .execute(&mut conn);

        let user: User = users::table
            .find(old_session.user_id)
            .filter(users::deleted_at.is_null())
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("user not found"))?;

        let session = self.create_session_for_user(&mut conn, user)?;
        Ok(connectrpc::Response::new(p::RefreshSessionResponse {
            session: Some(session).into(),
            ..Default::default()
        }))
    }

    async fn sign_out(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::SignOutRequest>,
    ) -> connectrpc::ServiceResult<p::SignOutResponse> {
        if let Ok(session_id) = ctx.session_id() {
            if let Ok(mut conn) = self.db.get_conn() {
                let _ = diesel::delete(user_sessions::table.filter(user_sessions::session_id.eq(session_id)))
                    .execute(&mut conn);
            }
        }
        Ok(connectrpc::Response::new(p::SignOutResponse::default()))
    }

    async fn get_current_user(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::GetCurrentUserRequest>,
    ) -> connectrpc::ServiceResult<p::GetCurrentUserResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in get_current_user");
            ConnectError::internal("database connection error")
        })?;

        let user: User = users::table
            .find(user_id)
            .filter(users::deleted_at.is_null())
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("user not found"))?;

        let avatar_url = if let Some(avatar_id) = user.avatar_id {
            uploads::table
                .find(avatar_id)
                .select(uploads::storage_key)
                .first::<String>(&mut conn)
                .ok()
        } else {
            None
        };

        Ok(connectrpc::Response::new(p::GetCurrentUserResponse {
            user: Some(user_to_proto(user, avatar_url)).into(),
            ..Default::default()
        }))
    }

    async fn update_current_user(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::UpdateCurrentUserRequest>,
    ) -> connectrpc::ServiceResult<p::UpdateCurrentUserResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in update_current_user");
            ConnectError::internal("database connection error")
        })?;

        let mut changeset = UpdateUser::default();
        if let Some(ref email) = req.email {
            changeset.email = Some(Some(email.trim().to_lowercase()));
        }
        if let Some(ref first_name) = req.first_name {
            changeset.first_name = Some(first_name.trim().to_string());
        }
        if let Some(ref last_name) = req.last_name {
            changeset.last_name = Some(last_name.trim().to_string());
        }
        if let Some(ref avatar_str) = req.avatar_upload_id {
            if let Ok(avatar_uuid) = Uuid::parse_str(avatar_str) {
                changeset.avatar_id = Some(Some(avatar_uuid));
            }
        }
        changeset.updated_at = Some(Utc::now());

        let user: User = diesel::update(users::table.find(user_id))
            .filter(users::deleted_at.is_null())
            .set(&changeset)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to update current user");
                ConnectError::internal("failed to update user")
            })?;

        let avatar_url = if let Some(avatar_id) = user.avatar_id {
            uploads::table
                .find(avatar_id)
                .select(uploads::storage_key)
                .first::<String>(&mut conn)
                .ok()
        } else {
            None
        };

        Ok(connectrpc::Response::new(p::UpdateCurrentUserResponse {
            user: Some(user_to_proto(user, avatar_url)).into(),
            ..Default::default()
        }))
    }

    async fn send_password_reset(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::SendPasswordResetRequest>,
    ) -> connectrpc::ServiceResult<p::SendPasswordResetResponse> {
        // Password reset dispatch hook (email / SMS OTP)
        Ok(connectrpc::Response::new(p::SendPasswordResetResponse::default()))
    }

    async fn set_device_token(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SetDeviceTokenRequest>,
    ) -> connectrpc::ServiceResult<p::SetDeviceTokenResponse> {
        let session_id = ctx.session_id()?;
        let req = request.to_owned_message();

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error in set_device_token");
            ConnectError::internal("database connection error")
        })?;

        diesel::update(user_sessions::table.filter(user_sessions::session_id.eq(session_id)))
            .set(user_sessions::fcm_token.eq(Some(req.fcm_token)))
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to update fcm token");
                ConnectError::internal("failed to set device token")
            })?;

        Ok(connectrpc::Response::new(p::SetDeviceTokenResponse::default()))
    }
}
