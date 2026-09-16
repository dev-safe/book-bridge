use super::helpers::user_to_summary;
use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::{NewReview, Review, User};
use crate::schema::{reviews, uploads, users};
use crate::utils::dt_to_proto;
use bigdecimal::BigDecimal;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct ReviewService {
    db: Arc<Database>,
}

impl ReviewService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }
}

impl p::ReviewService for ReviewService {
    async fn create_review(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateReviewRequest>,
    ) -> connectrpc::ServiceResult<p::CreateReviewResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let reviewee_id = Uuid::parse_str(&req.reviewee_id)
            .map_err(|_| ConnectError::invalid_argument("invalid reviewee ID format"))?;

        let transaction_id = if !req.transaction_id.trim().is_empty() {
            Uuid::parse_str(&req.transaction_id).ok()
        } else {
            None
        };

        if req.rating < 1 || req.rating > 5 {
            return Err(ConnectError::invalid_argument("rating must be between 1 and 5"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let review_id = Uuid::now_v7();
        let new_review = NewReview {
            id: review_id,
            author_id: user_id,
            reviewee_id: Some(reviewee_id),
            transaction_id,
            rating: BigDecimal::from(req.rating),
            content: if req.content.trim().is_empty() {
                None
            } else {
                Some(req.content.trim().to_string())
            },
        };

        let rev: Review = diesel::insert_into(reviews::table)
            .values(&new_review)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create review");
                ConnectError::internal("failed to create review")
            })?;

        // Recompute reviewee's aggregate rating in users table (since business logic lives in backend!)
        let all_ratings: Vec<BigDecimal> = reviews::table
            .filter(reviews::reviewee_id.eq(reviewee_id))
            .select(reviews::rating)
            .load(&mut conn)
            .unwrap_or_default();

        if !all_ratings.is_empty() {
            let sum: f64 = all_ratings.iter().filter_map(|r| r.to_string().parse::<f64>().ok()).sum();
            let avg = sum / (all_ratings.len() as f64);
            if let Some(avg_bd) = BigDecimal::parse_bytes(format!("{:.2}", avg).as_bytes(), 10) {
                let _ = diesel::update(users::table.find(reviewee_id))
                    .set(users::rating.eq(avg_bd))
                    .execute(&mut conn);
            }
        }

        let author: User = users::table.find(user_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("author not found")
        })?;

        let author_avatar = if let Some(av_id) = author.avatar_id {
            uploads::table
                .find(av_id)
                .select(uploads::storage_key)
                .first::<String>(&mut conn)
                .ok()
        } else {
            None
        };

        let proto_review = p::Review {
            id: rev.id.to_string(),
            author: Some(user_to_summary(author, author_avatar)).into(),
            reviewee_id: req.reviewee_id,
            rating: req.rating,
            content: rev.content.unwrap_or_default(),
            created_at: Some(dt_to_proto(rev.created_at)).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::CreateReviewResponse {
            review: Some(proto_review).into(),
            ..Default::default()
        }))
    }

    async fn list_user_reviews(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListUserReviewsRequest>,
    ) -> connectrpc::ServiceResult<p::ListUserReviewsResponse> {
        let req = request.to_owned_message();
        let target_user_id = Uuid::parse_str(&req.user_id)
            .map_err(|_| ConnectError::invalid_argument("invalid user ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let revs: Vec<Review> = reviews::table
            .filter(reviews::reviewee_id.eq(target_user_id))
            .order(reviews::created_at.desc())
            .limit(limit)
            .load(&mut conn)
            .unwrap_or_default();

        let mut proto_reviews = Vec::new();
        for r in revs {
            let author: Option<User> = users::table.find(r.author_id).first(&mut conn).ok();
            let author_avatar = if let Some(ref a) = author {
                if let Some(av_id) = a.avatar_id {
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

            let rating_int: i32 = r.rating.to_string().parse::<f64>().map(|v| v.round() as i32).unwrap_or(5);

            proto_reviews.push(p::Review {
                id: r.id.to_string(),
                author: author.map(|a| user_to_summary(a, author_avatar)).into(),
                reviewee_id: req.user_id.clone(),
                rating: rating_int,
                content: r.content.unwrap_or_default(),
                created_at: Some(dt_to_proto(r.created_at)).into(),
                ..Default::default()
            });
        }

        Ok(connectrpc::Response::new(p::ListUserReviewsResponse {
            reviews: proto_reviews,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn has_reviewed_transaction(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::HasReviewedTransactionRequest>,
    ) -> connectrpc::ServiceResult<p::HasReviewedTransactionResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let tx_id = Uuid::parse_str(&req.transaction_id)
            .map_err(|_| ConnectError::invalid_argument("invalid transaction ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let count: i64 = reviews::table
            .filter(reviews::author_id.eq(user_id))
            .filter(reviews::transaction_id.eq(Some(tx_id)))
            .count()
            .get_result(&mut conn)
            .unwrap_or(0);

        Ok(connectrpc::Response::new(p::HasReviewedTransactionResponse {
            has_reviewed: count > 0,
            ..Default::default()
        }))
    }
}
