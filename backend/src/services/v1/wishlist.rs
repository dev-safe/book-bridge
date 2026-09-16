use super::helpers::{
    book_condition_to_proto, book_picture_type_to_proto, book_status_to_proto, user_to_summary,
};
use super::proto as p;
use crate::db::Database;
use crate::middleware::AuthContextExt;
use crate::models::{Book, BookCategory, BookPicture, IndexedLocation, NewWishlistItem, Upload, User, WishlistItem};
use crate::schema::{
    book_categories, book_pictures, books, indexed_locations, uploads, users, wishlist_items,
};
use crate::utils::dt_to_proto;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct WishlistService {
    db: Arc<Database>,
}

impl WishlistService {
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

impl p::WishlistService for WishlistService {
    async fn list_wishlist(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListWishlistRequest>,
    ) -> connectrpc::ServiceResult<p::ListWishlistResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let items: Vec<WishlistItem> = wishlist_items::table
            .filter(wishlist_items::user_id.eq(user_id))
            .order(wishlist_items::created_at.desc())
            .limit(limit)
            .load(&mut conn)
            .unwrap_or_default();

        let mut proto_books = Vec::new();
        for item in items {
            if let Ok(b) = books::table.find(item.book_id).first::<Book>(&mut conn) {
                if let Ok(pb) = self.load_full_book(&mut conn, b) {
                    proto_books.push(pb);
                }
            }
        }

        Ok(connectrpc::Response::new(p::ListWishlistResponse {
            books: proto_books,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn add_book_to_wishlist(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::AddBookToWishlistRequest>,
    ) -> connectrpc::ServiceResult<p::AddBookToWishlistResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let book_id = Uuid::parse_str(&req.book_id)
            .map_err(|_| ConnectError::invalid_argument("invalid book ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let new_item = NewWishlistItem { user_id, book_id };
        let _ = diesel::insert_into(wishlist_items::table)
            .values(&new_item)
            .on_conflict_do_nothing()
            .execute(&mut conn);

        Ok(connectrpc::Response::new(p::AddBookToWishlistResponse {
            added: true,
            ..Default::default()
        }))
    }

    async fn remove_book_from_wishlist(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::RemoveBookFromWishlistRequest>,
    ) -> connectrpc::ServiceResult<p::RemoveBookFromWishlistResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let book_id = Uuid::parse_str(&req.book_id)
            .map_err(|_| ConnectError::invalid_argument("invalid book ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let count = diesel::delete(
            wishlist_items::table
                .filter(wishlist_items::user_id.eq(user_id))
                .filter(wishlist_items::book_id.eq(book_id)),
        )
        .execute(&mut conn)
        .unwrap_or(0);

        Ok(connectrpc::Response::new(p::RemoveBookFromWishlistResponse {
            removed: count > 0,
            ..Default::default()
        }))
    }

    async fn is_book_in_wishlist(
        &self,
        ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::IsBookInWishlistRequest>,
    ) -> connectrpc::ServiceResult<p::IsBookInWishlistResponse> {
        let user_id = ctx.user_id()?;
        let req = request.to_owned_message();
        let book_id = Uuid::parse_str(&req.book_id)
            .map_err(|_| ConnectError::invalid_argument("invalid book ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let count: i64 = wishlist_items::table
            .filter(wishlist_items::user_id.eq(user_id))
            .filter(wishlist_items::book_id.eq(book_id))
            .count()
            .get_result(&mut conn)
            .unwrap_or(0);

        Ok(connectrpc::Response::new(p::IsBookInWishlistResponse {
            is_favorite: count > 0,
            ..Default::default()
        }))
    }
}
