use super::proto as p;
use crate::db::Database;
use crate::fapshi::{DirectPayRequest, Fapshi};
use crate::middleware::AuthContextExt;
use crate::models::{
    Book, Boost, NewBoost, NewDonation, NewPayment, NewPaymentIntent,
    PaymentIntent, PaymentMethod, PaymentStatus, User,
};
use crate::schema::{books, boosts, donations, payment_intents, payments, users};
use crate::utils::dt_to_proto;
use chrono::{Duration, Utc};
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct BoostService {
    db: Arc<Database>,
    fapshi: Arc<Fapshi>,
}

impl BoostService {
    pub fn new(db: Arc<Database>, fapshi: Arc<Fapshi>) -> Self {
        Self { db, fapshi }
    }
}

impl p::BoostService for BoostService {
    async fn create_boost(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateBoostRequest>,
    ) -> connectrpc::ServiceResult<p::CreateBoostResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let book_id = Uuid::parse_str(&req.book_id)
            .map_err(|_| ConnectError::invalid_argument("invalid book ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let book: Book = books::table
            .find(book_id)
            .filter(books::deleted_at.is_null())
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("book not found"))?;

        if book.seller_id != user_id {
            return Err(ConnectError::permission_denied("can only boost your own book"));
        }

        let user: User = users::table.find(user_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("user not found")
        })?;

        let intent_id = Uuid::now_v7();
        let new_intent = NewPaymentIntent {
            id: intent_id,
            user_id,
            method: PaymentMethod::Fapshi,
            amount: req.amount_fcfa as i32,
            status: PaymentStatus::Pending,
        };

        diesel::insert_into(payment_intents::table)
            .values(&new_intent)
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create payment intent");
                ConnectError::internal("payment intent creation failed")
            })?;

        let fapshi_payload = DirectPayRequest {
            amount: req.amount_fcfa as u64,
            phone: &user.phone,
            network: None,
            name: Some(&user.first_name),
            email: user.email.as_deref(),
            user_id: Some(&user.id.to_string()),
            trans_id: Some(&intent_id.to_string()),
            reason: Some("Book promotion boost"),
        };

        let fapshi_res = self.fapshi.direct_pay(&fapshi_payload).await.map_err(|err| {
            tracing::error!(%err, "Fapshi payment request failed");
            ConnectError::internal("payment gateway error")
        })?;

        let external_ref = fapshi_res.trans_id.unwrap_or_else(|| intent_id.to_string());
        let new_payment = NewPayment {
            intent_id,
            platform_transaction_reference: external_ref.clone(),
        };

        diesel::insert_into(payments::table)
            .values(&new_payment)
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create payment record");
                ConnectError::internal("payment record creation failed")
            })?;

        let expires_at = Utc::now() + Duration::days(7);
        let new_boost = NewBoost {
            payment_id: intent_id,
            book_id,
            expires_at,
        };

        diesel::insert_into(boosts::table)
            .values(&new_boost)
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create boost record");
                ConnectError::internal("boost creation failed")
            })?;

        // Update book boost expiry
        let _ = diesel::update(books::table.find(book_id))
            .set(books::boost_expires_at.eq(expires_at))
            .execute(&mut conn);

        let proto_boost = p::Boost {
            id: intent_id.to_string(),
            book_id: book_id.to_string(),
            amount_fcfa: req.amount_fcfa,
            expires_at: Some(dt_to_proto(expires_at)).into(),
            created_at: Some(dt_to_proto(Utc::now())).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::CreateBoostResponse {
            boost: Some(proto_boost).into(),
            fapshi_transaction_id: external_ref,
            ..Default::default()
        }))
    }

    async fn get_boost_status(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetBoostStatusRequest>,
    ) -> connectrpc::ServiceResult<p::GetBoostStatusResponse> {
        let req = request.to_owned_message();
        let boost_id = Uuid::parse_str(&req.boost_id)
            .map_err(|_| ConnectError::invalid_argument("invalid boost ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let boost: Boost = boosts::table
            .find(boost_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("boost not found"))?;

        let intent: PaymentIntent = payment_intents::table
            .find(boost.payment_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("payment not found"))?;

        let proto_boost = p::Boost {
            id: boost.payment_id.to_string(),
            book_id: boost.book_id.to_string(),
            amount_fcfa: intent.amount as i64,
            expires_at: Some(dt_to_proto(boost.expires_at)).into(),
            created_at: Some(dt_to_proto(boost.created_at)).into(),
            ..Default::default()
        };

        let outcome = p::PaymentOutcome {
            status: format!("{:?}", intent.status),
            message: if boost.expires_at > Utc::now() && intent.status == PaymentStatus::Completed {
                "active".to_string()
            } else {
                "inactive".to_string()
            },
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::GetBoostStatusResponse {
            boost: Some(proto_boost).into(),
            outcome: Some(outcome).into(),
            ..Default::default()
        }))
    }
}

pub struct DonationService {
    db: Arc<Database>,
    fapshi: Arc<Fapshi>,
}

impl DonationService {
    pub fn new(db: Arc<Database>, fapshi: Arc<Fapshi>) -> Self {
        Self { db, fapshi }
    }
}

impl p::DonationService for DonationService {
    async fn create_donation(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateDonationRequest>,
    ) -> connectrpc::ServiceResult<p::CreateDonationResponse> {
        let user_id = ctx.user_id().ok();
        let req = request.to_owned_message();

        if req.amount_fcfa <= 0 {
            return Err(ConnectError::invalid_argument("donation amount must be greater than 0"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let donor_phone = if let Some(uid) = user_id {
            users::table
                .find(uid)
                .select(users::phone)
                .first::<String>(&mut conn)
                .unwrap_or_else(|_| "+237600000000".to_string())
        } else {
            "+237600000000".to_string()
        };

        let intent_id = Uuid::now_v7();
        let new_intent = NewPaymentIntent {
            id: intent_id,
            user_id: user_id.unwrap_or_else(Uuid::now_v7),
            method: PaymentMethod::Fapshi,
            amount: req.amount_fcfa as i32,
            status: PaymentStatus::Pending,
        };

        let _ = diesel::insert_into(payment_intents::table)
            .values(&new_intent)
            .execute(&mut conn);

        let fapshi_payload = DirectPayRequest {
            amount: req.amount_fcfa as u64,
            phone: &donor_phone,
            network: None,
            name: Some("BookBridge Supporter"),
            email: None,
            user_id: None,
            trans_id: Some(&intent_id.to_string()),
            reason: Some("Platform Donation"),
        };

        let external_ref = match self.fapshi.direct_pay(&fapshi_payload).await {
            Ok(r) => r.trans_id.unwrap_or_else(|| intent_id.to_string()),
            Err(_) => intent_id.to_string(),
        };

        let new_payment = NewPayment {
            intent_id,
            platform_transaction_reference: external_ref.clone(),
        };
        let _ = diesel::insert_into(payments::table).values(&new_payment).execute(&mut conn);

        let new_donation = NewDonation {
            payment_id: intent_id,
            user_id,
            message: if req.message.trim().is_empty() {
                None
            } else {
                Some(req.message.trim().to_string())
            },
        };
        let _ = diesel::insert_into(donations::table).values(&new_donation).execute(&mut conn);

        let proto_donation = p::Donation {
            id: intent_id.to_string(),
            amount_fcfa: req.amount_fcfa,
            message: req.message.trim().to_string(),
            created_at: Some(dt_to_proto(Utc::now())).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::CreateDonationResponse {
            donation: Some(proto_donation).into(),
            fapshi_transaction_id: external_ref,
            ..Default::default()
        }))
    }
}
