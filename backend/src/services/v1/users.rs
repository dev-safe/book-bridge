use super::helpers::user_to_summary;
use super::proto as p;
use crate::db::Database;
use crate::models::User;
use crate::schema::{uploads, users};
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct UserService {
    db: Arc<Database>,
}

impl UserService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }
}

impl p::UserService for UserService {
    async fn get_user(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetUserRequest>,
    ) -> connectrpc::ServiceResult<p::GetUserResponse> {
        let req = request.to_owned_message();
        let user_id = Uuid::parse_str(&req.user_id)
            .map_err(|_| ConnectError::invalid_argument("invalid user ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
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

        let summary = user_to_summary(user, avatar_url);
        Ok(connectrpc::Response::new(p::GetUserResponse {
            user: Some(summary).into(),
            ..Default::default()
        }))
    }
}
