use axum::{
    middleware,
    routing::{get, post},
    Router,
};
use sqlx::PgPool;
use std::sync::Arc;
use tokio::net::TcpListener;

use bookbridge_rust_core::auth::require_internal_auth;
use bookbridge_rust_core::config::AppConfig;
use bookbridge_rust_core::rate_limit::{limit_by_ip, RateLimits};
use bookbridge_rust_core::routes::admin::admin_routes;
use bookbridge_rust_core::routes::buyer::buyer_routes;
use bookbridge_rust_core::routes::escrow::{poll_pending_handler, process_releases_handler};
use bookbridge_rust_core::routes::health::health_handler;
use bookbridge_rust_core::push::PushService;
use bookbridge_rust_core::routes::payments::payment_routes;
use bookbridge_rust_core::routes::push::dispatch_push_handler;
use bookbridge_rust_core::routes::subscriptions::subscription_routes;
use bookbridge_rust_core::routes::webhook::fapshi_webhook_handler;
use bookbridge_rust_core::user_auth::SupabaseAuth;
use bookbridge_rust_core::AppState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing subscriber
    let _ = tracing_subscriber::fmt()
        .with_env_filter(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info,bookbridge_rust_core=debug".into()),
        )
        .try_init();

    tracing::info!("Initializing bookbridge-rust-core on Render...");

    // 1. Load config
    let config = AppConfig::load()?;
    let shared_config = Arc::new(config.clone());

    // 2. Setup database connection pool
    let pool = PgPool::connect(&config.database_url).await?;

    // 3. Setup AppState
    let state = AppState {
        pool,
        in_progress_payouts: Arc::new(std::sync::Mutex::new(std::collections::HashSet::new())),
        supabase_auth: SupabaseAuth::new(
            config.supabase_url.clone(),
            config.supabase_anon_key.clone(),
        ),
        fapshi_base_url: config.fapshi_base_url,
        rate_limits: RateLimits::new(config.rate_limits),
        push: PushService::from_env(),
    };

    // 4. Build authenticated routes
    let internal_routes = Router::new()
        .route("/escrow/process-releases", post(process_releases_handler))
        .route("/escrow/poll-pending", post(poll_pending_handler))
        .route("/push/dispatch", post(dispatch_push_handler))
        .layer(middleware::from_fn_with_state(
            shared_config.clone(),
            require_internal_auth,
        ))
        .with_state(state.clone());

    // 5. Main router. Health and webhooks are public / custom authenticated;
    //    buyer routes require a Supabase access token; admin routes also
    //    require a row in admin_users.
    //    Public routes are rate limited per client IP. Health checks and the
    //    cron-only internal routes are not.
    let public_routes = Router::new()
        .route("/webhooks/fapshi", post(fapshi_webhook_handler))
        .merge(buyer_routes())
        .merge(payment_routes())
        .merge(admin_routes())
        .merge(subscription_routes())
        .layer(middleware::from_fn_with_state(state.clone(), limit_by_ip));

    let app = Router::new()
        .route("/health", get(health_handler))
        .merge(public_routes)
        .nest("/internal", internal_routes)
        .with_state(state);

    // 6. Run Axum server using standard TcpListener
    let addr = format!("0.0.0.0:{}", config.port);
    tracing::info!("Starting Axum server on {}", addr);
    let listener = TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
