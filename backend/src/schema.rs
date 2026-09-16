// @generated automatically by Diesel CLI.

pub mod sql_types {
    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "location_type"))]
    pub struct LocationType;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "book_condition"))]
    pub struct BookCondition;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "book_picture_type"))]
    pub struct BookPictureType;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "book_status"))]
    pub struct BookStatus;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "payment_type"))]
    pub struct PaymentType;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "payment_status"))]
    pub struct PaymentStatus;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "payment_method"))]
    pub struct PaymentMethod;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "transaction_status"))]
    pub struct TransactionStatus;

    #[derive(diesel::query_builder::QueryId, Clone, diesel::sql_types::SqlType)]
    #[diesel(postgres_type(name = "verification_document_type"))]
    pub struct VerificationDocumentType;
}

diesel::table! {
    uploads (id) {
        id -> Uuid,
        #[max_length = 512]
        storage_key -> Varchar,
        #[max_length = 255]
        file_name -> Varchar,
        #[max_length = 100]
        content_type -> Varchar,
        size_bytes -> Int8,
        uploaded_by -> Nullable<Uuid>,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    users (id) {
        id -> Uuid,
        #[max_length = 255]
        email -> Nullable<Varchar>,
        #[max_length = 255]
        phone -> Varchar,
        #[max_length = 255]
        password_hash -> Nullable<Varchar>,
        #[max_length = 32]
        first_name -> Varchar,
        #[max_length = 32]
        last_name -> Varchar,
        avatar_id -> Nullable<Uuid>,
        rating -> Numeric,
        verified -> Bool,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    user_sessions (session_id) {
        session_id -> Uuid,
        user_id -> Uuid,
        refresh_token_hash -> Bytea,
        expires_at -> Timestamptz,
        rotated_at -> Timestamptz,
        fcm_token -> Nullable<Text>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::VerificationDocumentType;

    verification_documents (user_id, upload_id) {
        user_id -> Uuid,
        upload_id -> Uuid,
        document_type -> VerificationDocumentType,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::LocationType;

    indexed_locations (id) {
        id -> Uuid,
        #[sql_name = "type"]
        type_ -> LocationType,
        latitude -> Float8,
        longitude -> Float8,
        h3_3 -> Int8,
        h3_4 -> Int8,
        h3_5 -> Int8,
        h3_6 -> Int8,
        h3_7 -> Int8,
    }
}

diesel::table! {
    meetup_locations (id) {
        id -> Uuid,
        name -> Text,
        description -> Nullable<Text>,
        location_id -> Uuid,
        verified -> Bool,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    book_categories (id) {
        id -> Int8,
        #[max_length = 63]
        name -> Varchar,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{BookCondition, BookStatus};

    books (id) {
        id -> Uuid,
        seller_id -> Uuid,
        ebook_id -> Nullable<Uuid>,
        #[max_length = 255]
        title -> Varchar,
        #[max_length = 255]
        author -> Varchar,
        price -> Int4,
        condition -> BookCondition,
        description -> Nullable<Text>,
        status -> BookStatus,
        category -> Int8,
        refundable -> Bool,
        swapable -> Bool,
        boost_expires_at -> Timestamptz,
        expires_at -> Timestamptz,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
        location -> Nullable<Uuid>,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::BookPictureType;

    book_pictures (book_id, upload_id) {
        book_id -> Uuid,
        upload_id -> Uuid,
        #[sql_name = "type"]
        type_ -> BookPictureType,
    }
}

diesel::table! {
    conversations (id) {
        id -> Uuid,
        book_id -> Uuid,
        user_id -> Uuid,
        created_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    conversation_messages (id) {
        id -> Uuid,
        user_id -> Uuid,
        conversation_id -> Uuid,
        content -> Text,
        attachment -> Nullable<Uuid>,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    wishlist_items (user_id, book_id) {
        user_id -> Uuid,
        book_id -> Uuid,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    notification_templates (id) {
        id -> Uuid,
        parameters -> Jsonb,
    }
}

diesel::table! {
    notification_template_translations (template_id, lang) {
        template_id -> Uuid,
        #[max_length = 2]
        lang -> Varchar,
        format -> Text,
    }
}

diesel::table! {
    notification_bodies (id) {
        id -> Uuid,
        template_id -> Uuid,
        template_arguments -> Jsonb,
    }
}

diesel::table! {
    notifications (id) {
        id -> Uuid,
        user_id -> Nullable<Uuid>,
        body_id -> Nullable<Uuid>,
        template_arguments -> Jsonb,
        read_at -> Nullable<Timestamptz>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    reviews (id) {
        id -> Uuid,
        author_id -> Uuid,
        reviewee_id -> Nullable<Uuid>,
        transaction_id -> Nullable<Uuid>,
        rating -> Numeric,
        content -> Nullable<Text>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::{PaymentMethod, PaymentStatus};

    payment_intents (id) {
        id -> Uuid,
        user_id -> Uuid,
        method -> PaymentMethod,
        amount -> Int4,
        status -> PaymentStatus,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    payments (intent_id) {
        intent_id -> Uuid,
        platform_transaction_reference -> Text,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
    }
}

diesel::table! {
    use diesel::sql_types::*;
    use super::sql_types::TransactionStatus;

    transactions (payment_id) {
        payment_id -> Uuid,
        recipient -> Uuid,
        transaction_status -> TransactionStatus,
        created_at -> Timestamptz,
        updated_at -> Timestamptz,
        refunded_at -> Nullable<Timestamptz>,
        deleted_at -> Nullable<Timestamptz>,
    }
}

diesel::table! {
    boosts (payment_id) {
        payment_id -> Uuid,
        book_id -> Uuid,
        created_at -> Timestamptz,
        expires_at -> Timestamptz,
    }
}

diesel::table! {
    donations (payment_id) {
        payment_id -> Uuid,
        user_id -> Nullable<Uuid>,
        message -> Nullable<Text>,
        created_at -> Timestamptz,
    }
}

diesel::table! {
    book_purchases (transaction_id) {
        transaction_id -> Uuid,
        book_id -> Uuid,
        meetup_location -> Nullable<Uuid>,
        confirmed -> Bool,
        created_at -> Timestamptz,
    }
}

diesel::joinable!(users -> uploads (avatar_id));
diesel::joinable!(user_sessions -> users (user_id));
diesel::joinable!(verification_documents -> users (user_id));
diesel::joinable!(verification_documents -> uploads (upload_id));
diesel::joinable!(meetup_locations -> indexed_locations (location_id));
diesel::joinable!(books -> users (seller_id));
diesel::joinable!(books -> uploads (ebook_id));
diesel::joinable!(books -> book_categories (category));
diesel::joinable!(books -> indexed_locations (location));
diesel::joinable!(book_pictures -> books (book_id));
diesel::joinable!(book_pictures -> uploads (upload_id));
diesel::joinable!(conversations -> books (book_id));
diesel::joinable!(conversations -> users (user_id));
diesel::joinable!(conversation_messages -> conversations (conversation_id));
diesel::joinable!(conversation_messages -> users (user_id));
diesel::joinable!(conversation_messages -> uploads (attachment));
diesel::joinable!(wishlist_items -> users (user_id));
diesel::joinable!(wishlist_items -> books (book_id));
diesel::joinable!(notification_template_translations -> notification_templates (template_id));
diesel::joinable!(notification_bodies -> notification_templates (template_id));
diesel::joinable!(notifications -> users (user_id));
diesel::joinable!(notifications -> notification_bodies (body_id));
diesel::joinable!(reviews -> users (author_id));
diesel::joinable!(payment_intents -> users (user_id));
diesel::joinable!(payments -> payment_intents (intent_id));
diesel::joinable!(transactions -> payments (payment_id));
diesel::joinable!(transactions -> users (recipient));
diesel::joinable!(boosts -> payments (payment_id));
diesel::joinable!(boosts -> books (book_id));
diesel::joinable!(donations -> payments (payment_id));
diesel::joinable!(donations -> users (user_id));
diesel::joinable!(book_purchases -> transactions (transaction_id));
diesel::joinable!(book_purchases -> books (book_id));
diesel::joinable!(book_purchases -> meetup_locations (meetup_location));

diesel::allow_tables_to_appear_in_same_query!(
    uploads,
    users,
    user_sessions,
    verification_documents,
    indexed_locations,
    meetup_locations,
    book_categories,
    books,
    book_pictures,
    conversations,
    conversation_messages,
    wishlist_items,
    notification_templates,
    notification_template_translations,
    notification_bodies,
    notifications,
    reviews,
    payment_intents,
    payments,
    transactions,
    boosts,
    donations,
    book_purchases,
);
