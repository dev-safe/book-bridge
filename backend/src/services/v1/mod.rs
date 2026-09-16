pub use connectrpc::Router;
pub use std::sync::Arc;

pub mod auth;
pub mod books;
pub mod boosts;
pub mod chat;
pub mod helpers;
pub mod locations;
pub mod notifications;
pub mod proto;
pub mod purchases;
pub mod reviews;
pub mod stats;
pub mod uploads;
pub mod users;
pub mod wishlist;

pub fn include(
    router: Router,
    db: Arc<crate::db::Database>,
    jwt: Arc<crate::jwt::JWT>,
    fapshi: Arc<crate::fapshi::Fapshi>,
) -> Router {
    router
        .add_service(Arc::new(auth::AuthService::new(db.clone(), jwt.clone())))
        .add_service(Arc::new(books::BookService::new(db.clone())))
        .add_service(Arc::new(boosts::BoostService::new(db.clone(), fapshi.clone())))
        .add_service(Arc::new(boosts::DonationService::new(db.clone(), fapshi.clone())))
        .add_service(Arc::new(chat::ChatService::new(db.clone())))
        .add_service(Arc::new(locations::MeetupLocationService::new(db.clone())))
        .add_service(Arc::new(notifications::NotificationService::new(db.clone())))
        .add_service(Arc::new(purchases::PurchaseService::new(db.clone(), fapshi.clone())))
        .add_service(Arc::new(reviews::ReviewService::new(db.clone())))
        .add_service(Arc::new(stats::StatsService::new(db.clone())))
        .add_service(Arc::new(uploads::UploadService::new(db.clone())))
        .add_service(Arc::new(users::UserService::new(db.clone())))
        .add_service(Arc::new(wishlist::WishlistService::new(db.clone())))
}
