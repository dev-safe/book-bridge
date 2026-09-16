-- Drop tables in reverse order of foreign keys
drop table if exists book_purchases;
drop table if exists donations;
drop table if exists boosts;
drop table if exists reviews;
drop table if exists transactions;
drop table if exists payments;
drop table if exists payment_intents;
drop table if exists notifications;
drop table if exists notification_bodies;
drop table if exists notification_template_translations;
drop table if exists notification_templates;
drop table if exists wishlist_items;
drop table if exists conversation_messages;
drop table if exists conversations;
drop table if exists book_pictures;
drop table if exists books;
drop table if exists book_categories;
drop table if exists meetup_locations;
drop table if exists indexed_locations;
drop table if exists verification_documents;
drop table if exists user_sessions;
drop table if exists users;
drop table if exists uploads;

-- Drop custom types
drop type if exists verification_document_type;
drop type if exists transaction_status;
drop type if exists payment_method;
drop type if exists payment_status;
drop type if exists payment_type;
drop type if exists book_status;
drop type if exists book_picture_type;
drop type if exists book_condition;
drop type if exists location_type;

drop function if exists set_updated_at();
