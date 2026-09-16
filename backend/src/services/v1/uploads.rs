use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::{NewUpload, Upload};
use crate::schema::uploads;
use crate::utils::dt_to_proto;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct UploadService {
    db: Arc<Database>,
}

impl UploadService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }

    fn upload_to_proto(u: Upload) -> p::Upload {
        p::Upload {
            id: u.id.to_string(),
            storage_key: u.storage_key.clone(),
            file_name: u.file_name,
            content_type: u.content_type,
            size_bytes: u.size_bytes,
            url: format!("/uploads/{}", u.storage_key),
            created_at: Some(dt_to_proto(u.created_at)).into(),
            ..Default::default()
        }
    }
}

impl p::UploadService for UploadService {
    async fn create_upload(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateUploadRequest>,
    ) -> connectrpc::ServiceResult<p::CreateUploadResponse> {
        let user_id = ctx.user_id().ok();
        let req = request.to_owned_message();

        if req.file_name.trim().is_empty() {
            return Err(ConnectError::invalid_argument("file_name is required"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let upload_id = Uuid::now_v7();
        let storage_key = format!("{}-{}", upload_id, req.file_name.trim());
        let new_upload = NewUpload {
            id: upload_id,
            storage_key: storage_key.clone(),
            file_name: req.file_name.trim().to_string(),
            content_type: if req.content_type.is_empty() {
                "application/octet-stream".to_string()
            } else {
                req.content_type
            },
            size_bytes: if req.size_bytes > 0 { req.size_bytes } else { 1 },
            uploaded_by: user_id,
        };

        let u: Upload = diesel::insert_into(uploads::table)
            .values(&new_upload)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to insert upload");
                ConnectError::internal("failed to register upload")
            })?;

        let upload_url = format!("/api/v1/uploads/{}/bytes", upload_id);
        Ok(connectrpc::Response::new(p::CreateUploadResponse {
            upload: Some(Self::upload_to_proto(u)).into(),
            upload_url,
            ..Default::default()
        }))
    }

    async fn complete_upload(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CompleteUploadRequest>,
    ) -> connectrpc::ServiceResult<p::CompleteUploadResponse> {
        let req = request.to_owned_message();
        let upload_id = Uuid::parse_str(&req.upload_id)
            .map_err(|_| ConnectError::invalid_argument("invalid upload ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let u: Upload = uploads::table
            .find(upload_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("upload not found"))?;

        Ok(connectrpc::Response::new(p::CompleteUploadResponse {
            upload: Some(Self::upload_to_proto(u)).into(),
            ..Default::default()
        }))
    }

    async fn get_upload(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetUploadRequest>,
    ) -> connectrpc::ServiceResult<p::GetUploadResponse> {
        let req = request.to_owned_message();
        let upload_id = Uuid::parse_str(&req.upload_id)
            .map_err(|_| ConnectError::invalid_argument("invalid upload ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let u: Upload = uploads::table
            .find(upload_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("upload not found"))?;

        Ok(connectrpc::Response::new(p::GetUploadResponse {
            upload: Some(Self::upload_to_proto(u)).into(),
            ..Default::default()
        }))
    }

    async fn delete_upload(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::DeleteUploadRequest>,
    ) -> connectrpc::ServiceResult<p::DeleteUploadResponse> {
        let req = request.to_owned_message();
        let upload_id = Uuid::parse_str(&req.upload_id)
            .map_err(|_| ConnectError::invalid_argument("invalid upload ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let _ = diesel::delete(uploads::table.find(upload_id)).execute(&mut conn);
        Ok(connectrpc::Response::new(p::DeleteUploadResponse::default()))
    }
}
