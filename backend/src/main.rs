#![allow(refining_impl_trait_internal, refining_impl_trait_reachable)]

use connectrpc::{ConnectRpcService, Router};
use http::{Method, header};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tower_http::cors::CorsLayer;

mod config;
mod db;
mod fapshi;
mod jwt;
mod middleware;
mod models;
mod proto;
mod schema;
mod services;
mod utils;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    tracing_subscriber::fmt::init();

    let config = Arc::new(config::Config::load()?);

    // Allow migrations to be executed via `backend migrate` without starting the server
    if std::env::args().nth(1).as_deref() == Some("migrate") {
        tracing::info!("Running database migrations...");
        db::run_migrations(&config.database_url)?;
        tracing::info!("Database migrations executed successfully. Exiting.");
        return Ok(());
    }

    let db = Arc::new(db::Database::connect(&config)?);
    let jwt = Arc::new(jwt::JWT::new(&config.jwt_secret));
    let fapshi = Arc::new(fapshi::Fapshi::new(&config));

    let mut router = Router::new();
    router = services::v1::include(router, db.clone(), jwt.clone(), fapshi.clone());

    let cors = CorsLayer::new()
        .allow_origin(tower_http::cors::Any)
        .allow_methods([Method::GET, Method::POST, Method::OPTIONS])
        .allow_headers([
            header::AUTHORIZATION,
            header::CONTENT_TYPE,
            header::ACCEPT,
            header::HeaderName::from_static("connect-protocol-version"),
            header::HeaderName::from_static("connect-timeout-ms"),
            header::HeaderName::from_static("x-user-agent"),
            header::HeaderName::from_static("x-grpc-web"),
        ])
        .expose_headers([
            header::HeaderName::from_static("connect-protocol-version"),
            header::HeaderName::from_static("grpc-status"),
            header::HeaderName::from_static("grpc-message"),
            header::HeaderName::from_static("grpc-status-details-bin"),
        ])
        .max_age(Duration::from_secs(3600));

    let connect_service = ConnectRpcService::new(router)
        .with_interceptor(middleware::LoggingInterceptor::new())
        .with_interceptor(middleware::AuthInterceptor::new(&config.jwt_secret));

    let app = axum::Router::new()
        .fallback_service(connect_service)
        .layer(cors);

    let addr: SocketAddr = format!("0.0.0.0:{}", config.port).parse()?;
    tracing::info!("Starting BookBridge ConnectRPC server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
