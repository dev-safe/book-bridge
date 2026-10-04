pub mod auth;
pub mod config;
pub mod error;
pub mod fapshi;
pub mod push;
pub mod rate_limit;
pub mod routes;
pub mod user_auth;
pub mod verification;

use sqlx::PgPool;
use std::collections::HashSet;
use std::sync::Arc;
use std::sync::Mutex;
use uuid::Uuid;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub in_progress_payouts: Arc<Mutex<HashSet<Uuid>>>,
    pub fapshi_base_url: String,
    pub supabase_auth: user_auth::SupabaseAuth,
    pub rate_limits: rate_limit::RateLimits,
    pub push: push::PushService,
}
