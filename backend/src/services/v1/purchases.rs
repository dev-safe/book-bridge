use super::proto as p;
use crate::db::Database;
use crate::fapshi::{DirectPayRequest, Fapshi};
use crate::middleware::AuthContextExt;
use crate::models::{
    Book, BookPurchase, NewBookPurchase, NewPayment, NewPaymentIntent, NewTransaction,
    PaymentIntent, PaymentMethod, PaymentStatus, Transaction, TransactionStatus, User,
};
use crate::schema::{
    book_purchases, books, payment_intents, payments, transactions, users,
};
use crate::utils::dt_to_proto;
use chrono::Utc;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct PurchaseService {
    db: Arc<Database>,
    fapshi: Arc<Fapshi>,
}

impl PurchaseService {
    pub fn new(db: Arc<Database>, fapshi: Arc<Fapshi>) -> Self {
        Self { db, fapshi }
    }

    fn tx_status_to_proto(s: TransactionStatus) -> p::TransactionStatus {
        match s {
            TransactionStatus::Held => p::TransactionStatus::TRANSACTION_STATUS_HELD,
            TransactionStatus::Released => p::TransactionStatus::TRANSACTION_STATUS_RELEASED,
            TransactionStatus::Refunded => p::TransactionStatus::TRANSACTION_STATUS_REFUNDED,
            TransactionStatus::Disputed => p::TransactionStatus::TRANSACTION_STATUS_DISPUTED,
        }
    }
}

impl p::PurchaseService for PurchaseService {
    async fn create_book_purchase(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateBookPurchaseRequest>,
    ) -> connectrpc::ServiceResult<p::CreateBookPurchaseResponse> {
        let buyer_id = ctx.user_id()?;
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

        let buyer: User = users::table.find(buyer_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("buyer profile not found")
        })?;

        let meetup_location_id = req
            .meetup_location_id
            .as_deref()
            .and_then(|id| Uuid::parse_str(id).ok());

        let intent_id = Uuid::now_v7();
        let new_intent = NewPaymentIntent {
            id: intent_id,
            user_id: buyer_id,
            method: PaymentMethod::Fapshi,
            amount: book.price,
            status: PaymentStatus::Pending,
        };

        diesel::insert_into(payment_intents::table)
            .values(&new_intent)
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create payment intent");
                ConnectError::internal("failed to create payment intent")
            })?;

        let fapshi_payload = DirectPayRequest {
            amount: book.price as u64,
            phone: &buyer.phone,
            network: None,
            name: Some(&buyer.first_name),
            email: buyer.email.as_deref(),
            user_id: Some(&buyer_id.to_string()),
            trans_id: Some(&intent_id.to_string()),
            reason: Some("BookBridge Purchase"),
        };

        let fapshi_res = self.fapshi.direct_pay(&fapshi_payload).await.map_err(|err| {
            tracing::error!(%err, "Fapshi direct-pay failed");
            ConnectError::internal("payment gateway error")
        })?;

        let external_ref = fapshi_res.trans_id.unwrap_or_else(|| intent_id.to_string());
        let new_payment = NewPayment {
            intent_id,
            platform_transaction_reference: external_ref.clone(),
        };
        diesel::insert_into(payments::table).values(&new_payment).execute(&mut conn).map_err(|_| {
            ConnectError::internal("payment record creation failed")
        })?;

        let new_tx = NewTransaction {
            payment_id: intent_id,
            recipient: book.seller_id,
            transaction_status: TransactionStatus::Held,
        };
        diesel::insert_into(transactions::table).values(&new_tx).execute(&mut conn).map_err(|_| {
            ConnectError::internal("transaction creation failed")
        })?;

        let new_purchase = NewBookPurchase {
            transaction_id: intent_id,
            book_id,
            meetup_location: meetup_location_id,
            confirmed: false,
        };
        diesel::insert_into(book_purchases::table).values(&new_purchase).execute(&mut conn).map_err(|_| {
            ConnectError::internal("purchase creation failed")
        })?;

        let proto_purchase = p::Purchase {
            id: intent_id.to_string(),
            transaction_id: intent_id.to_string(),
            book: Some(p::BookPurchaseDetails {
                book_id: book.id.to_string(),
                title: book.title,
                cover_url: String::new(),
                price_fcfa: book.price as i64,
                meetup_location: None.into(),
                ..Default::default()
            }).into(),
            buyer_id: buyer_id.to_string(),
            status: p::TransactionStatus::TRANSACTION_STATUS_HELD.into(),
            confirmed: false,
            created_at: Some(dt_to_proto(Utc::now())).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::CreateBookPurchaseResponse {
            purchase: Some(proto_purchase).into(),
            fapshi_transaction_id: external_ref,
            ..Default::default()
        }))
    }

    async fn get_purchase(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetPurchaseRequest>,
    ) -> connectrpc::ServiceResult<p::GetPurchaseResponse> {
        let _user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let purchase_id = Uuid::parse_str(&req.purchase_id)
            .map_err(|_| ConnectError::invalid_argument("invalid purchase ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let purchase: BookPurchase = book_purchases::table
            .find(purchase_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("purchase not found"))?;

        let tx: Transaction = transactions::table
            .find(purchase.transaction_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("transaction not found"))?;

        let intent: PaymentIntent = payment_intents::table
            .find(purchase.transaction_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("payment not found"))?;

        let book: Book = books::table
            .find(purchase.book_id)
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("book not found"))?;

        let proto_purchase = p::Purchase {
            id: purchase.transaction_id.to_string(),
            transaction_id: purchase.transaction_id.to_string(),
            book: Some(p::BookPurchaseDetails {
                book_id: book.id.to_string(),
                title: book.title,
                cover_url: String::new(),
                price_fcfa: book.price as i64,
                meetup_location: None.into(),
                ..Default::default()
            }).into(),
            buyer_id: intent.user_id.to_string(),
            status: Self::tx_status_to_proto(tx.transaction_status).into(),
            confirmed: purchase.confirmed,
            created_at: Some(dt_to_proto(purchase.created_at)).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::GetPurchaseResponse {
            purchase: Some(proto_purchase).into(),
            ..Default::default()
        }))
    }

    async fn list_my_purchases(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::ListMyPurchasesRequest>,
    ) -> connectrpc::ServiceResult<p::ListMyPurchasesResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let user_intents: Vec<PaymentIntent> = payment_intents::table
            .filter(payment_intents::user_id.eq(user_id))
            .load(&mut conn)
            .unwrap_or_default();

        let intent_ids: Vec<Uuid> = user_intents.iter().map(|i| i.id).collect();
        let purchases: Vec<BookPurchase> = book_purchases::table
            .filter(book_purchases::transaction_id.eq_any(intent_ids))
            .load(&mut conn)
            .unwrap_or_default();

        let mut proto_purchases = Vec::new();
        for p in purchases {
            let tx: Option<Transaction> = transactions::table.find(p.transaction_id).first(&mut conn).ok();
            let book: Option<Book> = books::table.find(p.book_id).first(&mut conn).ok();

            if let Some(b) = book {
                let status = tx
                    .map(|t| Self::tx_status_to_proto(t.transaction_status))
                    .unwrap_or(p::TransactionStatus::TRANSACTION_STATUS_HELD);

                proto_purchases.push(p::Purchase {
                    id: p.transaction_id.to_string(),
                    transaction_id: p.transaction_id.to_string(),
                    book: Some(p::BookPurchaseDetails {
                        book_id: b.id.to_string(),
                        title: b.title,
                        cover_url: String::new(),
                        price_fcfa: b.price as i64,
                        meetup_location: None.into(),
                        ..Default::default()
                    }).into(),
                    buyer_id: user_id.to_string(),
                    status: status.into(),
                    confirmed: p.confirmed,
                    created_at: Some(dt_to_proto(p.created_at)).into(),
                    ..Default::default()
                });
            }
        }

        Ok(connectrpc::Response::new(p::ListMyPurchasesResponse {
            purchases: proto_purchases,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn list_my_sales(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::ListMySalesRequest>,
    ) -> connectrpc::ServiceResult<p::ListMySalesResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let txs: Vec<Transaction> = transactions::table
            .filter(transactions::recipient.eq(user_id))
            .load(&mut conn)
            .unwrap_or_default();

        let mut proto_sales = Vec::new();
        for tx in txs {
            if let Ok(bp) = book_purchases::table.find(tx.payment_id).first::<BookPurchase>(&mut conn) {
                if let Ok(b) = books::table.find(bp.book_id).first::<Book>(&mut conn) {
                    let buyer_id = payment_intents::table
                        .find(tx.payment_id)
                        .select(payment_intents::user_id)
                        .first::<Uuid>(&mut conn)
                        .unwrap_or(user_id);

                    proto_sales.push(p::Sale {
                        id: bp.transaction_id.to_string(),
                        transaction_id: tx.payment_id.to_string(),
                        book: Some(p::BookPurchaseDetails {
                            book_id: b.id.to_string(),
                            title: b.title,
                            cover_url: String::new(),
                            price_fcfa: b.price as i64,
                            meetup_location: None.into(),
                            ..Default::default()
                        }).into(),
                        buyer_id: buyer_id.to_string(),
                        status: Self::tx_status_to_proto(tx.transaction_status).into(),
                        created_at: Some(dt_to_proto(tx.created_at)).into(),
                        ..Default::default()
                    });
                }
            }
        }

        Ok(connectrpc::Response::new(p::ListMySalesResponse {
            sales: proto_sales,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn confirm_receipt(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ConfirmReceiptRequest>,
    ) -> connectrpc::ServiceResult<p::ConfirmReceiptResponse> {
        let _user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let purchase_id = Uuid::parse_str(&req.purchase_id)
            .map_err(|_| ConnectError::invalid_argument("invalid purchase ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        diesel::update(transactions::table.find(purchase_id))
            .set((
                transactions::transaction_status.eq(TransactionStatus::Released),
                transactions::updated_at.eq(Utc::now()),
            ))
            .execute(&mut conn)
            .map_err(|_| ConnectError::internal("failed to release escrow transaction"))?;

        diesel::update(book_purchases::table.find(purchase_id))
            .set(book_purchases::confirmed.eq(true))
            .execute(&mut conn)
            .map_err(|_| ConnectError::internal("failed to confirm purchase"))?;

        let purchase: BookPurchase = book_purchases::table.find(purchase_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("purchase not found")
        })?;
        let book: Book = books::table.find(purchase.book_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("book not found")
        })?;

        let proto_purchase = p::Purchase {
            id: purchase.transaction_id.to_string(),
            transaction_id: purchase.transaction_id.to_string(),
            book: Some(p::BookPurchaseDetails {
                book_id: book.id.to_string(),
                title: book.title,
                cover_url: String::new(),
                price_fcfa: book.price as i64,
                meetup_location: None.into(),
                ..Default::default()
            }).into(),
            buyer_id: _user_id.to_string(),
            status: p::TransactionStatus::TRANSACTION_STATUS_RELEASED.into(),
            confirmed: true,
            created_at: Some(dt_to_proto(purchase.created_at)).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::ConfirmReceiptResponse {
            purchase: Some(proto_purchase).into(),
            ..Default::default()
        }))
    }

    async fn dispute_purchase(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::DisputePurchaseRequest>,
    ) -> connectrpc::ServiceResult<p::DisputePurchaseResponse> {
        let _user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let purchase_id = Uuid::parse_str(&req.purchase_id)
            .map_err(|_| ConnectError::invalid_argument("invalid purchase ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        diesel::update(transactions::table.find(purchase_id))
            .set((
                transactions::transaction_status.eq(TransactionStatus::Disputed),
                transactions::updated_at.eq(Utc::now()),
            ))
            .execute(&mut conn)
            .map_err(|_| ConnectError::internal("failed to dispute escrow transaction"))?;

        let purchase: BookPurchase = book_purchases::table.find(purchase_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("purchase not found")
        })?;
        let book: Book = books::table.find(purchase.book_id).first(&mut conn).map_err(|_| {
            ConnectError::not_found("book not found")
        })?;

        let proto_purchase = p::Purchase {
            id: purchase.transaction_id.to_string(),
            transaction_id: purchase.transaction_id.to_string(),
            book: Some(p::BookPurchaseDetails {
                book_id: book.id.to_string(),
                title: book.title,
                cover_url: String::new(),
                price_fcfa: book.price as i64,
                meetup_location: None.into(),
                ..Default::default()
            }).into(),
            buyer_id: _user_id.to_string(),
            status: p::TransactionStatus::TRANSACTION_STATUS_DISPUTED.into(),
            confirmed: purchase.confirmed,
            created_at: Some(dt_to_proto(purchase.created_at)).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::DisputePurchaseResponse {
            purchase: Some(proto_purchase).into(),
            ..Default::default()
        }))
    }
}
