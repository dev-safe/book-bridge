use super::helpers::{
    book_condition_from_proto, book_condition_to_proto, book_picture_type_from_proto,
    book_picture_type_to_proto, book_status_from_proto, book_status_to_proto, lat_lng_to_h3_indices,
    user_to_summary,
};
use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::{
    Book, BookCategory, BookPicture, BookStatus, IndexedLocation,
    LocationType, NewBook, NewBookPicture, NewIndexedLocation, UpdateBook, Upload, User,
};
use crate::schema::{
    book_categories, book_pictures, books, indexed_locations, uploads, users,
};
use crate::utils::dt_to_proto;
use chrono::{Duration, Utc};
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct BookService {
    db: Arc<Database>,
}

impl BookService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }

    fn load_full_book(
        &self,
        conn: &mut crate::db::PgPooledConnection,
        book: Book,
    ) -> Result<p::Book, ConnectError> {
        let seller: User = users::table
            .find(book.seller_id)
            .first(conn)
            .map_err(|_| ConnectError::not_found("seller not found"))?;

        let seller_avatar = if let Some(avatar_id) = seller.avatar_id {
            uploads::table
                .find(avatar_id)
                .select(uploads::storage_key)
                .first::<String>(conn)
                .ok()
        } else {
            None
        };

        let category: BookCategory = book_categories::table
            .find(book.category)
            .first(conn)
            .unwrap_or(BookCategory {
                id: book.category,
                name: "General".to_string(),
            });

        let pictures: Vec<(BookPicture, Upload)> = book_pictures::table
            .filter(book_pictures::book_id.eq(book.id))
            .inner_join(uploads::table.on(book_pictures::upload_id.eq(uploads::id)))
            .load::<(BookPicture, Upload)>(conn)
            .unwrap_or_default();

        let proto_pictures = pictures
            .into_iter()
            .map(|(bp, up)| p::BookPicture {
                upload_id: bp.upload_id.to_string(),
                url: up.storage_key,
                r#type: book_picture_type_to_proto(bp.type_).into(),
                ..Default::default()
            })
            .collect();

        let location = if let Some(loc_id) = book.location {
            indexed_locations::table
                .find(loc_id)
                .first::<IndexedLocation>(conn)
                .ok()
                .map(|loc| p::LatLng {
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    ..Default::default()
                })
        } else {
            None
        };

        Ok(p::Book {
            id: book.id.to_string(),
            seller: Some(user_to_summary(seller, seller_avatar)).into(),
            title: book.title,
            author: book.author,
            price_fcfa: book.price as i64,
            condition: book_condition_to_proto(book.condition).into(),
            description: book.description.unwrap_or_default(),
            status: book_status_to_proto(book.status).into(),
            category: Some(p::BookCategory {
                id: category.id,
                name: category.name,
                ..Default::default()
            })
            .into(),
            refundable: book.refundable,
            swapable: book.swapable,
            pictures: proto_pictures,
            ebook_id: book.ebook_id.map(|id| id.to_string()).unwrap_or_default(),
            boost_expires_at: Some(dt_to_proto(book.boost_expires_at)).into(),
            expires_at: Some(dt_to_proto(book.expires_at)).into(),
            created_at: Some(dt_to_proto(book.created_at)).into(),
            updated_at: Some(dt_to_proto(book.updated_at)).into(),
            location: location.into(),
            ..Default::default()
        })
    }
}

impl p::BookService for BookService {
    async fn list_categories(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::ListCategoriesRequest>,
    ) -> connectrpc::ServiceResult<p::ListCategoriesResponse> {
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let cats: Vec<BookCategory> = book_categories::table
            .order(book_categories::name.asc())
            .load(&mut conn)
            .unwrap_or_default();

        let proto_cats = cats
            .into_iter()
            .map(|c| p::BookCategory {
                id: c.id,
                name: c.name,
                ..Default::default()
            })
            .collect();

        Ok(connectrpc::Response::new(p::ListCategoriesResponse {
            categories: proto_cats,
            ..Default::default()
        }))
    }

    async fn list_books(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListBooksRequest>,
    ) -> connectrpc::ServiceResult<p::ListBooksResponse> {
        let req = request.to_owned_message();
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let mut query = books::table
            .filter(books::deleted_at.is_null())
            .into_boxed();

        let status = req.status.as_known();
        if let Some(s) = status {
            if s != p::BookStatus::BOOK_STATUS_UNSPECIFIED {
                query = query.filter(books::status.eq(book_status_from_proto(s)));
            }
        } else {
            query = query.filter(books::status.eq(BookStatus::Available));
        }

        if req.category_id > 0 {
            query = query.filter(books::category.eq(req.category_id));
        }

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let items: Vec<Book> = query
            .order((books::boost_expires_at.desc(), books::created_at.desc()))
            .limit(limit)
            .load(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to load books");
                ConnectError::internal("failed to query books")
            })?;

        let mut proto_books = Vec::new();
        for b in items {
            if let Ok(pb) = self.load_full_book(&mut conn, b) {
                proto_books.push(pb);
            }
        }

        Ok(connectrpc::Response::new(p::ListBooksResponse {
            books: proto_books,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn search_books(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::SearchBooksRequest>,
    ) -> connectrpc::ServiceResult<p::SearchBooksResponse> {
        let req = request.to_owned_message();
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let search_pattern = format!("%{}%", req.query.trim());
        let mut query = books::table
            .filter(books::deleted_at.is_null())
            .filter(books::status.eq(BookStatus::Available))
            .filter(books::title.ilike(search_pattern.clone()).or(books::author.ilike(search_pattern)))
            .into_boxed();

        if req.category_id > 0 {
            query = query.filter(books::category.eq(req.category_id));
        }

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let items: Vec<Book> = query
            .order(books::created_at.desc())
            .limit(limit)
            .load(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to search books");
                ConnectError::internal("failed to search books")
            })?;

        let mut proto_books = Vec::new();
        for b in items {
            if let Ok(pb) = self.load_full_book(&mut conn, b) {
                proto_books.push(pb);
            }
        }

        Ok(connectrpc::Response::new(p::SearchBooksResponse {
            books: proto_books,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn get_book(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetBookRequest>,
    ) -> connectrpc::ServiceResult<p::GetBookResponse> {
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

        let proto_book = self.load_full_book(&mut conn, book)?;
        Ok(connectrpc::Response::new(p::GetBookResponse {
            book: Some(proto_book).into(),
            ..Default::default()
        }))
    }

    async fn list_books_by_seller(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListBooksBySellerRequest>,
    ) -> connectrpc::ServiceResult<p::ListBooksBySellerResponse> {
        let req = request.to_owned_message();
        let seller_id = Uuid::parse_str(&req.seller_id)
            .map_err(|_| ConnectError::invalid_argument("invalid seller ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let items: Vec<Book> = books::table
            .filter(books::seller_id.eq(seller_id))
            .filter(books::deleted_at.is_null())
            .order(books::created_at.desc())
            .load(&mut conn)
            .map_err(|_| ConnectError::internal("failed to load books"))?;

        let mut proto_books = Vec::new();
        for b in items {
            if let Ok(pb) = self.load_full_book(&mut conn, b) {
                proto_books.push(pb);
            }
        }

        Ok(connectrpc::Response::new(p::ListBooksBySellerResponse {
            books: proto_books,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn list_my_books(
        &self,
        ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::ListMyBooksRequest>,
    ) -> connectrpc::ServiceResult<p::ListMyBooksResponse> {
        let user_id = ctx.user_id()?;
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let items: Vec<Book> = books::table
            .filter(books::seller_id.eq(user_id))
            .filter(books::deleted_at.is_null())
            .order(books::created_at.desc())
            .load(&mut conn)
            .map_err(|_| ConnectError::internal("failed to load user books"))?;

        let mut proto_books = Vec::new();
        for b in items {
            if let Ok(pb) = self.load_full_book(&mut conn, b) {
                proto_books.push(pb);
            }
        }

        Ok(connectrpc::Response::new(p::ListMyBooksResponse {
            books: proto_books,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn create_book(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::CreateBookRequest>,
    ) -> connectrpc::ServiceResult<p::CreateBookResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();

        if req.title.trim().is_empty() || req.author.trim().is_empty() {
            return Err(ConnectError::invalid_argument("title and author are required"));
        }

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let book_id = Uuid::now_v7();
        let expires_days = req.expires_in_days.unwrap_or(60);
        let expires_at = Utc::now() + Duration::days(expires_days as i64);

        let location_id = if let Some(loc) = req.location.as_option() {
            if let Ok((h3_3, h3_4, h3_5, h3_6, h3_7)) =
                lat_lng_to_h3_indices(loc.latitude, loc.longitude)
            {
                let loc_id = Uuid::now_v7();
                let new_loc = NewIndexedLocation {
                    id: loc_id,
                    type_: LocationType::Book,
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    h3_3,
                    h3_4,
                    h3_5,
                    h3_6,
                    h3_7,
                };
                diesel::insert_into(indexed_locations::table)
                    .values(&new_loc)
                    .execute(&mut conn)
                    .ok();
                Some(loc_id)
            } else {
                None
            }
        } else {
            None
        };

        let ebook_uuid = if !req.ebook_upload_id.is_empty() {
            Uuid::parse_str(&req.ebook_upload_id).ok()
        } else {
            None
        };

        let new_book = NewBook {
            id: book_id,
            seller_id: user_id,
            ebook_id: ebook_uuid,
            title: req.title.trim().to_string(),
            author: req.author.trim().to_string(),
            price: req.price_fcfa as i32,
            condition: book_condition_from_proto(req.condition.as_known().unwrap_or(p::BookCondition::BOOK_CONDITION_GOOD)),
            description: if req.description.trim().is_empty() {
                None
            } else {
                Some(req.description.trim().to_string())
            },
            status: BookStatus::Available,
            category: if req.category_id > 0 { req.category_id } else { 1 },
            refundable: req.refundable,
            swapable: req.swapable,
            expires_at,
            location: location_id,
        };

        let created_book: Book = diesel::insert_into(books::table)
            .values(&new_book)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to create book");
                ConnectError::internal("failed to create book")
            })?;

        for pic_upload_str in req.picture_upload_ids {
            if let Ok(pic_upload_id) = Uuid::parse_str(&pic_upload_str) {
                let p_type = req
                    .picture_types
                    .get(&pic_upload_str)
                    .copied()
                    .and_then(|v| v.as_known())
                    .unwrap_or(p::BookPictureType::BOOK_PICTURE_TYPE_OTHER);

                let new_pic = NewBookPicture {
                    book_id,
                    upload_id: pic_upload_id,
                    type_: book_picture_type_from_proto(p_type),
                };
                let _ = diesel::insert_into(book_pictures::table)
                    .values(&new_pic)
                    .execute(&mut conn);
            }
        }

        let proto_book = self.load_full_book(&mut conn, created_book)?;
        Ok(connectrpc::Response::new(p::CreateBookResponse {
            book: Some(proto_book).into(),
            ..Default::default()
        }))
    }

    async fn update_book(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::UpdateBookRequest>,
    ) -> connectrpc::ServiceResult<p::UpdateBookResponse> {
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
            return Err(ConnectError::permission_denied("cannot edit another seller's book"));
        }

        let mut changeset = UpdateBook::default();
        if let Some(t) = req.title {
            changeset.title = Some(t.trim().to_string());
        }
        if let Some(a) = req.author {
            changeset.author = Some(a.trim().to_string());
        }
        if let Some(price) = req.price_fcfa {
            changeset.price = Some(price as i32);
        }
        if let Some(cond) = req.condition {
            if let Some(c) = cond.as_known() {
                changeset.condition = Some(book_condition_from_proto(c));
            }
        }
        if let Some(desc) = req.description {
            changeset.description = Some(Some(desc.trim().to_string()));
        }
        if let Some(cat) = req.category_id {
            changeset.category = Some(cat);
        }
        if let Some(status) = req.status {
            if let Some(s) = status.as_known() {
                changeset.status = Some(book_status_from_proto(s));
            }
        }
        changeset.refundable = req.refundable;
        changeset.swapable = req.swapable;
        changeset.updated_at = Some(Utc::now());

        let updated_book: Book = diesel::update(books::table.find(book_id))
            .set(&changeset)
            .get_result(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to update book");
                ConnectError::internal("failed to update book")
            })?;

        let proto_book = self.load_full_book(&mut conn, updated_book)?;
        Ok(connectrpc::Response::new(p::UpdateBookResponse {
            book: Some(proto_book).into(),
            ..Default::default()
        }))
    }

    async fn delete_book(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::DeleteBookRequest>,
    ) -> connectrpc::ServiceResult<p::DeleteBookResponse> {
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
            return Err(ConnectError::permission_denied("cannot delete another seller's book"));
        }

        diesel::update(books::table.find(book_id))
            .set(books::deleted_at.eq(Some(Utc::now())))
            .execute(&mut conn)
            .map_err(|err| {
                tracing::error!(%err, "Failed to delete book");
                ConnectError::internal("failed to delete book")
            })?;

        Ok(connectrpc::Response::new(p::DeleteBookResponse::default()))
    }
}
