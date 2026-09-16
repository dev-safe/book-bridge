use super::helpers::user_to_summary;
use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::{Book, Conversation, ConversationMessage, NewConversation, NewConversationMessage, Upload, User};
use crate::schema::{books, conversation_messages, conversations, uploads, users};
use crate::utils::dt_to_proto;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct ChatService {
    db: Arc<Database>,
}

impl ChatService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }

    fn message_to_proto(
        &self,
        conn: &mut crate::db::PgPooledConnection,
        m: ConversationMessage,
    ) -> p::Message {
        let attachment = if let Some(att_id) = m.attachment {
            if let Ok(u) = uploads::table.find(att_id).first::<Upload>(conn) {
                Some(p::UploadAttachment {
                    upload_id: u.id.to_string(),
                    url: u.storage_key,
                    content_type: u.content_type,
                    file_name: u.file_name,
                    ..Default::default()
                })
            } else {
                None
            }
        } else {
            None
        };

        p::Message {
            id: m.id.to_string(),
            conversation_id: m.conversation_id.to_string(),
            user_id: m.user_id.to_string(),
            content: m.content,
            attachment: attachment.into(),
            created_at: Some(dt_to_proto(m.created_at)).into(),
            ..Default::default()
        }
    }
}

impl p::ChatService for ChatService {
    async fn list_conversations(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::ListConversationsRequest>,
    ) -> connectrpc::ServiceResult<p::ListConversationsResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let convs: Vec<Conversation> = conversations::table
            .filter(conversations::deleted_at.is_null())
            .filter(conversations::user_id.eq(user_id))
            .order(conversations::created_at.desc())
            .load(&mut conn)
            .map_err(|_| ConnectError::internal("failed to load conversations"))?;

        let mut proto_convs = Vec::new();
        for c in convs {
            let book: Option<Book> = books::table.find(c.book_id).first(&mut conn).ok();
            let other_user_id = if let Some(ref b) = book {
                if b.seller_id == user_id {
                    c.user_id
                } else {
                    b.seller_id
                }
            } else {
                c.user_id
            };

            let other_user = users::table.find(other_user_id).first::<User>(&mut conn).ok();
            let other_avatar = if let Some(ref u) = other_user {
                if let Some(av_id) = u.avatar_id {
                    uploads::table
                        .find(av_id)
                        .select(uploads::storage_key)
                        .first::<String>(&mut conn)
                        .ok()
                } else {
                    None
                }
            } else {
                None
            };

            let last_msg: Option<ConversationMessage> = conversation_messages::table
                .filter(conversation_messages::conversation_id.eq(c.id))
                .order(conversation_messages::created_at.desc())
                .first(&mut conn)
                .ok();

            let (last_message, last_message_at) = if let Some(m) = last_msg {
                (m.content, Some(dt_to_proto(m.created_at)))
            } else {
                (String::new(), None)
            };

            let book_summary = book.map(|b| p::BookSummary {
                id: b.id.to_string(),
                title: b.title,
                cover_url: String::new(),
                ..Default::default()
            });

            let other_participant = other_user.map(|u| user_to_summary(u, other_avatar));

            proto_convs.push(p::Conversation {
                id: c.id.to_string(),
                book_id: c.book_id.to_string(),
                book: book_summary.into(),
                other_participant: other_participant.into(),
                last_message,
                last_message_at: last_message_at.into(),
                unread_count: 0,
                ..Default::default()
            });
        }

        Ok(connectrpc::Response::new(p::ListConversationsResponse {
            conversations: proto_convs,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn get_or_create_conversation(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetOrCreateConversationRequest>,
    ) -> connectrpc::ServiceResult<p::GetOrCreateConversationResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let book_id = Uuid::parse_str(&req.book_id)
            .map_err(|_| ConnectError::invalid_argument("invalid book ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let existing: Option<Conversation> = conversations::table
            .filter(conversations::book_id.eq(book_id))
            .filter(conversations::user_id.eq(user_id))
            .filter(conversations::deleted_at.is_null())
            .first(&mut conn)
            .ok();

        let conv = match existing {
            Some(c) => c,
            None => {
                let new_id = Uuid::now_v7();
                let new_c = NewConversation {
                    id: new_id,
                    book_id,
                    user_id,
                };
                diesel::insert_into(conversations::table)
                    .values(&new_c)
                    .get_result(&mut conn)
                    .map_err(|err| {
                        tracing::error!(%err, "Failed to create conversation");
                        ConnectError::internal("failed to create conversation")
                    })?
            }
        };

        let book: Option<Book> = books::table.find(conv.book_id).first(&mut conn).ok();
        let seller_id = book.as_ref().map(|b| b.seller_id).unwrap_or(user_id);
        let other_user = users::table.find(seller_id).first::<User>(&mut conn).ok();
        let other_avatar = if let Some(ref u) = other_user {
            if let Some(av_id) = u.avatar_id {
                uploads::table
                    .find(av_id)
                    .select(uploads::storage_key)
                    .first::<String>(&mut conn)
                    .ok()
            } else {
                None
            }
        } else {
            None
        };

        let proto_conv = p::Conversation {
            id: conv.id.to_string(),
            book_id: conv.book_id.to_string(),
            book: book.map(|b| p::BookSummary {
                id: b.id.to_string(),
                title: b.title,
                cover_url: String::new(),
                ..Default::default()
            }).into(),
            other_participant: other_user.map(|u| user_to_summary(u, other_avatar)).into(),
            last_message: String::new(),
            last_message_at: None.into(),
            unread_count: 0,
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::GetOrCreateConversationResponse {
            conversation: Some(proto_conv).into(),
            ..Default::default()
        }))
    }

    async fn list_messages(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListMessagesRequest>,
    ) -> connectrpc::ServiceResult<p::ListMessagesResponse> {
        let _user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let conv_id = Uuid::parse_str(&req.conversation_id)
            .map_err(|_| ConnectError::invalid_argument("invalid conversation ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let messages: Vec<ConversationMessage> = conversation_messages::table
            .filter(conversation_messages::conversation_id.eq(conv_id))
            .filter(conversation_messages::deleted_at.is_null())
            .order(conversation_messages::created_at.asc())
            .limit(100)
            .load(&mut conn)
            .map_err(|_| ConnectError::internal("failed to load messages"))?;

        let proto_messages: Vec<p::Message> = messages
            .into_iter()
            .map(|m| self.message_to_proto(&mut conn, m))
            .collect();

        Ok(connectrpc::Response::new(p::ListMessagesResponse {
            messages: proto_messages,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn send_message(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SendMessageRequest>,
    ) -> connectrpc::ServiceResult<p::SendMessageResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let conv_id = Uuid::parse_str(&req.conversation_id)
            .map_err(|_| ConnectError::invalid_argument("invalid conversation ID format"))?;

        if req.content.trim().is_empty() && req.attachment_upload_id.trim().is_empty() {
            return Err(ConnectError::invalid_argument("message content or attachment is required"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let attachment_id = if !req.attachment_upload_id.trim().is_empty() {
            Uuid::parse_str(&req.attachment_upload_id).ok()
        } else {
            None
        };

        let msg_id = Uuid::now_v7();
        let new_msg = NewConversationMessage {
            id: msg_id,
            user_id,
            conversation_id: conv_id,
            content: req.content.trim().to_string(),
            attachment: attachment_id,
        };

        let msg: ConversationMessage = diesel::insert_into(conversation_messages::table)
            .values(&new_msg)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to insert message");
                ConnectError::internal("failed to send message")
            })?;

        let proto_msg = self.message_to_proto(&mut conn, msg);
        Ok(connectrpc::Response::new(p::SendMessageResponse {
            message: Some(proto_msg).into(),
            ..Default::default()
        }))
    }

    async fn mark_messages_read(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::MarkMessagesReadRequest>,
    ) -> connectrpc::ServiceResult<p::MarkMessagesReadResponse> {
        Ok(connectrpc::Response::new(p::MarkMessagesReadResponse::default()))
    }

    async fn stream_conversations(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::StreamConversationsRequest>,
    ) -> connectrpc::ServiceResult<connectrpc::ServiceStream<p::StreamConversationsResponse>> {
        let stream = async_stream::stream! {
            yield Ok::<_, ConnectError>(p::StreamConversationsResponse {
                ..Default::default()
            });
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(30)).await;
            }
        };

        Ok(connectrpc::Response::new(Box::pin(stream)))
    }
}
