-- =============================================================================
-- BookBridge — PostgreSQL Schema (Initial Setup)
-- =============================================================================

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create type location_type as enum ('book', 'meetup');
create type book_condition as enum ('new', 'like_new', 'good', 'fair', 'poor');
create type book_picture_type as enum ('front', 'back', 'other');
create type book_status as enum ('available', 'sold', 'reserved', 'expired', 'removed');
create type payment_type as enum ('book', 'donation', 'boost');
create type payment_status as enum ('pending', 'completed', 'failed');
create type payment_method as enum ('fapshi');
create type transaction_status as enum ('held', 'released', 'refunded', 'disputed');
create type verification_document_type as enum ('nationalid', 'schoolid');

-- =============================================================================
-- uploads
-- =============================================================================

create table if not exists uploads (
  id           uuid primary key default uuidv7(),
  storage_key  varchar(512) unique not null,
  file_name    varchar(255) not null,
  content_type varchar(100) not null,
  size_bytes   bigint not null check (size_bytes > 0),
  uploaded_by  uuid,
  created_at   timestamptz not null default current_timestamp,
  updated_at   timestamptz not null default current_timestamp
);

create or replace trigger trg_uploads_updated_at
  before update on uploads
  for each row execute function set_updated_at();

-- =============================================================================
-- users & auth
-- =============================================================================

create table if not exists users (
  id              uuid primary key default uuidv7(),
  email           varchar(255),
  phone           varchar(255) not null unique,
  password_hash   varchar(255),
  first_name      varchar(32) not null,
  last_name       varchar(32) not null,
  avatar_id       uuid references uploads(id) on delete set null,
  rating          numeric(3,2) not null default 0.00 check (rating between 0 and 5),
  verified        boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

alter table uploads add constraint fk_uploads_uploaded_by foreign key (uploaded_by) references users(id) on delete set null;

create or replace trigger trg_users_updated_at
  before update on users
  for each row execute function set_updated_at();

create index if not exists idx_users_phone on users (phone);
create index if not exists idx_users_email on users (email);
create index if not exists idx_uploads_uploaded_by on uploads (uploaded_by);

create table if not exists user_sessions (
  session_id         uuid primary key default uuidv7(),
  user_id            uuid not null references users(id) on delete cascade,
  refresh_token_hash bytea not null unique,
  expires_at         timestamptz not null,
  rotated_at         timestamptz not null default now(),
  fcm_token          text,
  created_at         timestamptz not null default now()
);

create index if not exists idx_user_sessions_user_id on user_sessions (user_id);

create table if not exists verification_documents (
  user_id       uuid not null references users(id) on delete cascade,
  upload_id     uuid not null references uploads(id) on delete cascade,
  document_type verification_document_type not null,
  created_at    timestamptz not null default now(),
  primary key (user_id, upload_id)
);

-- =============================================================================
-- geo / indexed locations
-- =============================================================================

create table if not exists indexed_locations (
  id        uuid primary key default uuidv7(),
  type      location_type not null,
  latitude  double precision not null,
  longitude double precision not null,
  h3_3      bigint not null,
  h3_4      bigint not null,
  h3_5      bigint not null,
  h3_6      bigint not null,
  h3_7      bigint not null
);

create index if not exists idx_indexed_locations_h3_3 on indexed_locations (h3_3);
create index if not exists idx_indexed_locations_h3_4 on indexed_locations (h3_4);
create index if not exists idx_indexed_locations_h3_5 on indexed_locations (h3_5);
create index if not exists idx_indexed_locations_h3_6 on indexed_locations (h3_6);
create index if not exists idx_indexed_locations_h3_7 on indexed_locations (h3_7);

create table if not exists meetup_locations (
  id          uuid primary key default uuidv7(),
  name        text not null,
  description text,
  location_id uuid not null references indexed_locations(id) on delete cascade,
  verified    boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_meetup_locations_location_id on meetup_locations (location_id);

-- =============================================================================
-- books
-- =============================================================================

create table if not exists book_categories (
  id   bigserial primary key,
  name varchar(63) not null unique
);

create table if not exists books (
  id               uuid primary key default uuidv7(),
  seller_id        uuid not null references users(id) on delete cascade,
  ebook_id         uuid references uploads(id) on delete set null,
  title            varchar(255) not null,
  author           varchar(255) not null,
  price            integer not null check (price >= 0),
  condition        book_condition not null,
  description      text,
  status           book_status not null default 'available',
  category         bigint not null references book_categories(id) on delete cascade,
  refundable       boolean not null default false,
  swapable         boolean not null default false,
  boost_expires_at timestamptz not null default now(),
  expires_at       timestamptz not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz,
  location         uuid references indexed_locations(id) on delete set null
);

create or replace trigger trg_books_updated_at
  before update on books
  for each row execute function set_updated_at();

create index if not exists idx_books_seller_id on books (seller_id);
create index if not exists idx_books_status on books (status);
create index if not exists idx_books_category on books (category);
create index if not exists idx_books_location on books (location);

create table if not exists book_pictures (
  book_id   uuid not null references books(id) on delete cascade,
  upload_id uuid not null references uploads(id) on delete cascade,
  type      book_picture_type not null default 'other',
  primary key (book_id, upload_id)
);

create index if not exists idx_book_pictures_upload_id on book_pictures (upload_id);

-- =============================================================================
-- messaging
-- =============================================================================

create table if not exists conversations (
  id         uuid primary key default uuidv7(),
  book_id    uuid not null references books(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_conversations_book_id on conversations (book_id);
create index if not exists idx_conversations_user_id on conversations (user_id);

create table if not exists conversation_messages (
  id              uuid primary key default uuidv7(),
  user_id         uuid not null references users(id) on delete cascade,
  conversation_id uuid not null references conversations(id) on delete cascade,
  content         text not null,
  attachment      uuid references uploads(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create or replace trigger trg_conversation_messages_updated_at
  before update on conversation_messages
  for each row execute function set_updated_at();

create index if not exists idx_conversation_messages_conversation_id
  on conversation_messages (conversation_id, created_at);
create index if not exists idx_conversation_messages_user_id on conversation_messages (user_id);

-- =============================================================================
-- wishlist
-- =============================================================================

create table if not exists wishlist_items (
  user_id    uuid not null references users(id) on delete cascade,
  book_id    uuid not null references books(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, book_id)
);

create index if not exists idx_wishlist_items_book_id on wishlist_items (book_id);

-- =============================================================================
-- notifications
-- =============================================================================

create table if not exists notification_templates (
  id         uuid primary key,
  parameters jsonb not null default '{}'
);

create table if not exists notification_template_translations (
  template_id uuid not null references notification_templates(id) on delete cascade,
  lang        varchar(2) not null,
  format      text not null,
  primary key (template_id, lang)
);

create table if not exists notification_bodies (
  id                 uuid primary key default uuidv7(),
  template_id        uuid not null references notification_templates(id) on delete cascade,
  template_arguments jsonb not null default '{}'
);

create index if not exists idx_notification_bodies_template_id on notification_bodies (template_id);

create table if not exists notifications (
  id                 uuid primary key default uuidv7(),
  user_id            uuid references users(id) on delete cascade,
  body_id            uuid references notification_bodies(id) on delete cascade,
  template_arguments jsonb not null default '{}',
  read_at            timestamptz,
  created_at         timestamptz not null default now()
);

create index if not exists idx_notifications_user_id on notifications (user_id, created_at desc);

-- =============================================================================
-- reviews
-- =============================================================================

create table if not exists reviews (
  id             uuid primary key default uuidv7(),
  author_id      uuid not null references users(id) on delete cascade,
  reviewee_id    uuid references users(id) on delete cascade,
  transaction_id uuid,
  rating         numeric(3,2) not null check (rating between 1 and 5),
  content        text,
  created_at     timestamptz not null default now()
);

create index if not exists idx_reviews_author_id on reviews (author_id);
create index if not exists idx_reviews_reviewee_id on reviews (reviewee_id);

-- =============================================================================
-- payments and transactions
-- =============================================================================

create table if not exists payment_intents (
  id         uuid primary key default uuidv7(),
  user_id    uuid not null references users(id) on delete cascade,
  method     payment_method not null,
  amount     integer not null check (amount > 0),
  status     payment_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace trigger trg_payment_intents_updated_at
  before update on payment_intents
  for each row execute function set_updated_at();

create index if not exists idx_payment_intents_user_id on payment_intents (user_id);

create table if not exists payments (
  intent_id                      uuid primary key references payment_intents(id) on delete cascade,
  platform_transaction_reference text not null,
  created_at                     timestamptz not null default now(),
  updated_at                     timestamptz not null default now()
);

create or replace trigger trg_payments_updated_at
  before update on payments
  for each row execute function set_updated_at();

create table if not exists transactions (
  payment_id         uuid primary key references payments(intent_id) on delete cascade,
  recipient          uuid not null references users(id) on delete cascade,
  transaction_status transaction_status not null default 'held',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  refunded_at        timestamptz,
  deleted_at         timestamptz
);

create or replace trigger trg_transactions_updated_at
  before update on transactions
  for each row execute function set_updated_at();

create index if not exists idx_transactions_recipient on transactions (recipient);

alter table reviews add constraint fk_reviews_transaction foreign key (transaction_id) references transactions(payment_id) on delete set null;

-- =============================================================================
-- payment types
-- =============================================================================

create table if not exists boosts (
  payment_id  uuid primary key references payments(intent_id) on delete cascade,
  book_id     uuid not null references books(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
);

create index if not exists idx_boosts_book_id on boosts (book_id);

create table if not exists donations (
  payment_id  uuid primary key references payments(intent_id) on delete cascade,
  user_id     uuid references users(id) on delete set null,
  message     text,
  created_at  timestamptz not null default now()
);

create index if not exists idx_donations_user_id on donations (user_id);

create table if not exists book_purchases (
  transaction_id  uuid primary key references transactions(payment_id) on delete cascade,
  book_id         uuid not null references books(id) on delete cascade,
  meetup_location uuid references meetup_locations(id) on delete set null,
  confirmed       boolean not null default false,
  created_at      timestamptz not null default now()
);

create index if not exists idx_book_purchases_book_id on book_purchases (book_id);
