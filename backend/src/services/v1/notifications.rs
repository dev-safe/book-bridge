use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::Notification;
use crate::schema::notifications;
use crate::utils::{dt_to_proto, opt_dt_to_proto};
use chrono::Utc;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct NotificationService {
    db: Arc<Database>,
}

impl NotificationService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }
}

impl p::NotificationService for NotificationService {
    async fn list_notifications(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListNotificationsRequest>,
    ) -> connectrpc::ServiceResult<p::ListNotificationsResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let mut query = notifications::table
            .filter(notifications::user_id.eq(user_id))
            .into_boxed();

        if req.unread_only {
            query = query.filter(notifications::read_at.is_null());
        }

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let items: Vec<Notification> = query
            .order(notifications::created_at.desc())
            .limit(limit)
            .load(&mut conn)
            .unwrap_or_default();

        let proto_notifs = items
            .into_iter()
            .map(|n| p::Notification {
                id: n.id.to_string(),
                title: "BookBridge Notification".to_string(),
                body: String::new(),
                r#type: "general".to_string(),
                read_at: opt_dt_to_proto(n.read_at),
                created_at: Some(dt_to_proto(n.created_at)).into(),
                ..Default::default()
            })
            .collect();

        Ok(connectrpc::Response::new(p::ListNotificationsResponse {
            notifications: proto_notifs,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn mark_notification_read(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::MarkNotificationReadRequest>,
    ) -> connectrpc::ServiceResult<p::MarkNotificationReadResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let notif_id = Uuid::parse_str(&req.notification_id)
            .map_err(|_| ConnectError::invalid_argument("invalid notification ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let _ = diesel::update(
            notifications::table
                .find(notif_id)
                .filter(notifications::user_id.eq(user_id)),
        )
        .set(notifications::read_at.eq(Some(Utc::now())))
        .execute(&mut conn);

        Ok(connectrpc::Response::new(p::MarkNotificationReadResponse::default()))
    }

    async fn mark_all_notifications_read(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::MarkAllNotificationsReadRequest>,
    ) -> connectrpc::ServiceResult<p::MarkAllNotificationsReadResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let _ = diesel::update(
            notifications::table
                .filter(notifications::user_id.eq(user_id))
                .filter(notifications::read_at.is_null()),
        )
        .set(notifications::read_at.eq(Some(Utc::now())))
        .execute(&mut conn);

        Ok(connectrpc::Response::new(p::MarkAllNotificationsReadResponse::default()))
    }

    async fn stream_notifications(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::StreamNotificationsRequest>,
    ) -> connectrpc::ServiceResult<connectrpc::ServiceStream<p::StreamNotificationsResponse>> {
        let stream = async_stream::stream! {
            yield Ok::<_, ConnectError>(p::StreamNotificationsResponse {
                ..Default::default()
            });
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(30)).await;
            }
        };

        Ok(connectrpc::Response::new(Box::pin(stream)))
    }
}
