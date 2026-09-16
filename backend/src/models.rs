#![allow(unused_imports)]

use crate::schema::sql_types::{
    BookCondition as SqlBookCondition, BookPictureType as SqlBookPictureType,
    BookStatus as SqlBookStatus, LocationType as SqlLocationType,
    PaymentMethod as SqlPaymentMethod, PaymentStatus as SqlPaymentStatus,
    PaymentType as SqlPaymentType, TransactionStatus as SqlTransactionStatus,
    VerificationDocumentType as SqlVerificationDocumentType,
};
use crate::schema::{
    book_categories, book_pictures, book_purchases, books, boosts, conversation_messages,
    conversations, donations, indexed_locations, meetup_locations, notification_bodies,
    notification_template_translations, notification_templates, notifications, payment_intents,
    payments, reviews, transactions, uploads, user_sessions, users, verification_documents,
    wishlist_items,
};
use bigdecimal::BigDecimal;
use chrono::{DateTime, Utc};
use diesel::deserialize::{self, FromSql, FromSqlRow};
use diesel::expression::AsExpression;
use diesel::pg::{Pg, PgValue};
use diesel::prelude::*;
use diesel::serialize::{self, IsNull, Output, ToSql};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use std::io::Write;
use uuid::Uuid;

// =============================================================================
// ENUMS
// =============================================================================

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlLocationType)]
pub enum LocationType {
    Book,
    Meetup,
}

impl ToSql<SqlLocationType, Pg> for LocationType {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            LocationType::Book => out.write_all(b"book")?,
            LocationType::Meetup => out.write_all(b"meetup")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlLocationType, Pg> for LocationType {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"book" => Ok(LocationType::Book),
            b"meetup" => Ok(LocationType::Meetup),
            _ => Err("Unrecognized enum variant for LocationType".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlBookCondition)]
pub enum BookCondition {
    New,
    LikeNew,
    Good,
    Fair,
    Poor,
}

impl ToSql<SqlBookCondition, Pg> for BookCondition {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            BookCondition::New => out.write_all(b"new")?,
            BookCondition::LikeNew => out.write_all(b"like_new")?,
            BookCondition::Good => out.write_all(b"good")?,
            BookCondition::Fair => out.write_all(b"fair")?,
            BookCondition::Poor => out.write_all(b"poor")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlBookCondition, Pg> for BookCondition {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"new" => Ok(BookCondition::New),
            b"like_new" => Ok(BookCondition::LikeNew),
            b"good" => Ok(BookCondition::Good),
            b"fair" => Ok(BookCondition::Fair),
            b"poor" => Ok(BookCondition::Poor),
            _ => Err("Unrecognized enum variant for BookCondition".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlBookPictureType)]
pub enum BookPictureType {
    Front,
    Back,
    Other,
}

impl ToSql<SqlBookPictureType, Pg> for BookPictureType {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            BookPictureType::Front => out.write_all(b"front")?,
            BookPictureType::Back => out.write_all(b"back")?,
            BookPictureType::Other => out.write_all(b"other")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlBookPictureType, Pg> for BookPictureType {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"front" => Ok(BookPictureType::Front),
            b"back" => Ok(BookPictureType::Back),
            b"other" => Ok(BookPictureType::Other),
            _ => Err("Unrecognized enum variant for BookPictureType".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlBookStatus)]
pub enum BookStatus {
    Available,
    Sold,
    Reserved,
    Expired,
    Removed,
}

impl ToSql<SqlBookStatus, Pg> for BookStatus {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            BookStatus::Available => out.write_all(b"available")?,
            BookStatus::Sold => out.write_all(b"sold")?,
            BookStatus::Reserved => out.write_all(b"reserved")?,
            BookStatus::Expired => out.write_all(b"expired")?,
            BookStatus::Removed => out.write_all(b"removed")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlBookStatus, Pg> for BookStatus {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"available" => Ok(BookStatus::Available),
            b"sold" => Ok(BookStatus::Sold),
            b"reserved" => Ok(BookStatus::Reserved),
            b"expired" => Ok(BookStatus::Expired),
            b"removed" => Ok(BookStatus::Removed),
            _ => Err("Unrecognized enum variant for BookStatus".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlPaymentType)]
pub enum PaymentType {
    Book,
    Donation,
    Boost,
}

impl ToSql<SqlPaymentType, Pg> for PaymentType {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            PaymentType::Book => out.write_all(b"book")?,
            PaymentType::Donation => out.write_all(b"donation")?,
            PaymentType::Boost => out.write_all(b"boost")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlPaymentType, Pg> for PaymentType {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"book" => Ok(PaymentType::Book),
            b"donation" => Ok(PaymentType::Donation),
            b"boost" => Ok(PaymentType::Boost),
            _ => Err("Unrecognized enum variant for PaymentType".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlPaymentStatus)]
pub enum PaymentStatus {
    Pending,
    Completed,
    Failed,
}

impl ToSql<SqlPaymentStatus, Pg> for PaymentStatus {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            PaymentStatus::Pending => out.write_all(b"pending")?,
            PaymentStatus::Completed => out.write_all(b"completed")?,
            PaymentStatus::Failed => out.write_all(b"failed")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlPaymentStatus, Pg> for PaymentStatus {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"pending" => Ok(PaymentStatus::Pending),
            b"completed" => Ok(PaymentStatus::Completed),
            b"failed" => Ok(PaymentStatus::Failed),
            _ => Err("Unrecognized enum variant for PaymentStatus".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlPaymentMethod)]
pub enum PaymentMethod {
    Fapshi,
}

impl ToSql<SqlPaymentMethod, Pg> for PaymentMethod {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            PaymentMethod::Fapshi => out.write_all(b"fapshi")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlPaymentMethod, Pg> for PaymentMethod {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"fapshi" => Ok(PaymentMethod::Fapshi),
            _ => Err("Unrecognized enum variant for PaymentMethod".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlTransactionStatus)]
pub enum TransactionStatus {
    Held,
    Released,
    Refunded,
    Disputed,
}

impl ToSql<SqlTransactionStatus, Pg> for TransactionStatus {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            TransactionStatus::Held => out.write_all(b"held")?,
            TransactionStatus::Released => out.write_all(b"released")?,
            TransactionStatus::Refunded => out.write_all(b"refunded")?,
            TransactionStatus::Disputed => out.write_all(b"disputed")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlTransactionStatus, Pg> for TransactionStatus {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"held" => Ok(TransactionStatus::Held),
            b"released" => Ok(TransactionStatus::Released),
            b"refunded" => Ok(TransactionStatus::Refunded),
            b"disputed" => Ok(TransactionStatus::Disputed),
            _ => Err("Unrecognized enum variant for TransactionStatus".into()),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, AsExpression, FromSqlRow)]
#[diesel(sql_type = SqlVerificationDocumentType)]
pub enum VerificationDocumentType {
    NationalId,
    SchoolId,
}

impl ToSql<SqlVerificationDocumentType, Pg> for VerificationDocumentType {
    fn to_sql<'b>(&'b self, out: &mut Output<'b, '_, Pg>) -> serialize::Result {
        match self {
            VerificationDocumentType::NationalId => out.write_all(b"nationalid")?,
            VerificationDocumentType::SchoolId => out.write_all(b"schoolid")?,
        }
        Ok(IsNull::No)
    }
}

impl FromSql<SqlVerificationDocumentType, Pg> for VerificationDocumentType {
    fn from_sql(bytes: PgValue) -> deserialize::Result<Self> {
        match bytes.as_bytes() {
            b"nationalid" => Ok(VerificationDocumentType::NationalId),
            b"schoolid" => Ok(VerificationDocumentType::SchoolId),
            _ => Err("Unrecognized enum variant for VerificationDocumentType".into()),
        }
    }
}

// =============================================================================
// MODELS
// =============================================================================

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = uploads)]
pub struct Upload {
    pub id: Uuid,
    pub storage_key: String,
    pub file_name: String,
    pub content_type: String,
    pub size_bytes: i64,
    pub uploaded_by: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = uploads)]
pub struct NewUpload {
    pub id: Uuid,
    pub storage_key: String,
    pub file_name: String,
    pub content_type: String,
    pub size_bytes: i64,
    pub uploaded_by: Option<Uuid>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = users)]
pub struct User {
    pub id: Uuid,
    pub email: Option<String>,
    pub phone: String,
    pub password_hash: Option<String>,
    pub first_name: String,
    pub last_name: String,
    pub avatar_id: Option<Uuid>,
    pub rating: BigDecimal,
    pub verified: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = users)]
pub struct NewUser {
    pub id: Uuid,
    pub email: Option<String>,
    pub phone: String,
    pub password_hash: Option<String>,
    pub first_name: String,
    pub last_name: String,
    pub avatar_id: Option<Uuid>,
}

#[derive(Debug, Clone, Default, AsChangeset)]
#[diesel(table_name = users)]
pub struct UpdateUser {
    pub email: Option<Option<String>>,
    pub phone: Option<String>,
    pub password_hash: Option<Option<String>>,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub avatar_id: Option<Option<Uuid>>,
    pub rating: Option<BigDecimal>,
    pub verified: Option<bool>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = user_sessions, primary_key(session_id))]
pub struct UserSession {
    pub session_id: Uuid,
    pub user_id: Uuid,
    pub refresh_token_hash: Vec<u8>,
    pub expires_at: DateTime<Utc>,
    pub rotated_at: DateTime<Utc>,
    pub fcm_token: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = user_sessions)]
pub struct NewUserSession {
    pub session_id: Uuid,
    pub user_id: Uuid,
    pub refresh_token_hash: Vec<u8>,
    pub expires_at: DateTime<Utc>,
    pub fcm_token: Option<String>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = verification_documents, primary_key(user_id, upload_id))]
pub struct VerificationDocument {
    pub user_id: Uuid,
    pub upload_id: Uuid,
    pub document_type: VerificationDocumentType,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = verification_documents)]
pub struct NewVerificationDocument {
    pub user_id: Uuid,
    pub upload_id: Uuid,
    pub document_type: VerificationDocumentType,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = indexed_locations)]
pub struct IndexedLocation {
    pub id: Uuid,
    pub type_: LocationType,
    pub latitude: f64,
    pub longitude: f64,
    pub h3_3: i64,
    pub h3_4: i64,
    pub h3_5: i64,
    pub h3_6: i64,
    pub h3_7: i64,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = indexed_locations)]
pub struct NewIndexedLocation {
    pub id: Uuid,
    pub type_: LocationType,
    pub latitude: f64,
    pub longitude: f64,
    pub h3_3: i64,
    pub h3_4: i64,
    pub h3_5: i64,
    pub h3_6: i64,
    pub h3_7: i64,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = meetup_locations)]
pub struct MeetupLocation {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub location_id: Uuid,
    pub verified: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = meetup_locations)]
pub struct NewMeetupLocation {
    pub id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub location_id: Uuid,
    pub verified: bool,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = book_categories)]
pub struct BookCategory {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = book_categories)]
pub struct NewBookCategory {
    pub name: String,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = books)]
pub struct Book {
    pub id: Uuid,
    pub seller_id: Uuid,
    pub ebook_id: Option<Uuid>,
    pub title: String,
    pub author: String,
    pub price: i32,
    pub condition: BookCondition,
    pub description: Option<String>,
    pub status: BookStatus,
    pub category: i64,
    pub refundable: bool,
    pub swapable: bool,
    pub boost_expires_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub location: Option<Uuid>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = books)]
pub struct NewBook {
    pub id: Uuid,
    pub seller_id: Uuid,
    pub ebook_id: Option<Uuid>,
    pub title: String,
    pub author: String,
    pub price: i32,
    pub condition: BookCondition,
    pub description: Option<String>,
    pub status: BookStatus,
    pub category: i64,
    pub refundable: bool,
    pub swapable: bool,
    pub expires_at: DateTime<Utc>,
    pub location: Option<Uuid>,
}

#[derive(Debug, Clone, Default, AsChangeset)]
#[diesel(table_name = books)]
pub struct UpdateBook {
    pub title: Option<String>,
    pub author: Option<String>,
    pub price: Option<i32>,
    pub condition: Option<BookCondition>,
    pub description: Option<Option<String>>,
    pub status: Option<BookStatus>,
    pub category: Option<i64>,
    pub refundable: Option<bool>,
    pub swapable: Option<bool>,
    pub location: Option<Option<Uuid>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = book_pictures, primary_key(book_id, upload_id))]
pub struct BookPicture {
    pub book_id: Uuid,
    pub upload_id: Uuid,
    pub type_: BookPictureType,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = book_pictures)]
pub struct NewBookPicture {
    pub book_id: Uuid,
    pub upload_id: Uuid,
    pub type_: BookPictureType,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = conversations)]
pub struct Conversation {
    pub id: Uuid,
    pub book_id: Uuid,
    pub user_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = conversations)]
pub struct NewConversation {
    pub id: Uuid,
    pub book_id: Uuid,
    pub user_id: Uuid,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = conversation_messages)]
pub struct ConversationMessage {
    pub id: Uuid,
    pub user_id: Uuid,
    pub conversation_id: Uuid,
    pub content: String,
    pub attachment: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = conversation_messages)]
pub struct NewConversationMessage {
    pub id: Uuid,
    pub user_id: Uuid,
    pub conversation_id: Uuid,
    pub content: String,
    pub attachment: Option<Uuid>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = wishlist_items, primary_key(user_id, book_id))]
pub struct WishlistItem {
    pub user_id: Uuid,
    pub book_id: Uuid,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = wishlist_items)]
pub struct NewWishlistItem {
    pub user_id: Uuid,
    pub book_id: Uuid,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = notification_templates)]
pub struct NotificationTemplate {
    pub id: Uuid,
    pub parameters: JsonValue,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = notification_template_translations, primary_key(template_id, lang))]
pub struct NotificationTemplateTranslation {
    pub template_id: Uuid,
    pub lang: String,
    pub format: String,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = notification_bodies)]
pub struct NotificationBody {
    pub id: Uuid,
    pub template_id: Uuid,
    pub template_arguments: JsonValue,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = notifications)]
pub struct Notification {
    pub id: Uuid,
    pub user_id: Option<Uuid>,
    pub body_id: Option<Uuid>,
    pub template_arguments: JsonValue,
    pub read_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = notifications)]
pub struct NewNotification {
    pub id: Uuid,
    pub user_id: Option<Uuid>,
    pub body_id: Option<Uuid>,
    pub template_arguments: JsonValue,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = reviews)]
pub struct Review {
    pub id: Uuid,
    pub author_id: Uuid,
    pub reviewee_id: Option<Uuid>,
    pub transaction_id: Option<Uuid>,
    pub rating: BigDecimal,
    pub content: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = reviews)]
pub struct NewReview {
    pub id: Uuid,
    pub author_id: Uuid,
    pub reviewee_id: Option<Uuid>,
    pub transaction_id: Option<Uuid>,
    pub rating: BigDecimal,
    pub content: Option<String>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = payment_intents)]
pub struct PaymentIntent {
    pub id: Uuid,
    pub user_id: Uuid,
    pub method: PaymentMethod,
    pub amount: i32,
    pub status: PaymentStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = payment_intents)]
pub struct NewPaymentIntent {
    pub id: Uuid,
    pub user_id: Uuid,
    pub method: PaymentMethod,
    pub amount: i32,
    pub status: PaymentStatus,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = payments, primary_key(intent_id))]
pub struct Payment {
    pub intent_id: Uuid,
    pub platform_transaction_reference: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = payments)]
pub struct NewPayment {
    pub intent_id: Uuid,
    pub platform_transaction_reference: String,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = transactions, primary_key(payment_id))]
pub struct Transaction {
    pub payment_id: Uuid,
    pub recipient: Uuid,
    pub transaction_status: TransactionStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub refunded_at: Option<DateTime<Utc>>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = transactions)]
pub struct NewTransaction {
    pub payment_id: Uuid,
    pub recipient: Uuid,
    pub transaction_status: TransactionStatus,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = boosts, primary_key(payment_id))]
pub struct Boost {
    pub payment_id: Uuid,
    pub book_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = boosts)]
pub struct NewBoost {
    pub payment_id: Uuid,
    pub book_id: Uuid,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = donations, primary_key(payment_id))]
pub struct Donation {
    pub payment_id: Uuid,
    pub user_id: Option<Uuid>,
    pub message: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = donations)]
pub struct NewDonation {
    pub payment_id: Uuid,
    pub user_id: Option<Uuid>,
    pub message: Option<String>,
}

#[derive(Debug, Clone, Queryable, Selectable, Identifiable, Serialize, Deserialize)]
#[diesel(table_name = book_purchases, primary_key(transaction_id))]
pub struct BookPurchase {
    pub transaction_id: Uuid,
    pub book_id: Uuid,
    pub meetup_location: Option<Uuid>,
    pub confirmed: bool,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Insertable)]
#[diesel(table_name = book_purchases)]
pub struct NewBookPurchase {
    pub transaction_id: Uuid,
    pub book_id: Uuid,
    pub meetup_location: Option<Uuid>,
    pub confirmed: bool,
}
