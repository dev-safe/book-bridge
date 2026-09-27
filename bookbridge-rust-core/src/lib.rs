pub mod auth;
pub mod config;
pub mod error;
pub mod fapshi;
pub mod routes;
pub mod user_auth;

use std::sync::Arc;
use std::sync::Mutex;
use std::collections::HashSet;
use uuid::Uuid;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub in_progress_payouts: Arc<Mutex<HashSet<Uuid>>>,
    pub fapshi_base_url: String,
    pub supabase_auth: user_auth::SupabaseAuth,
}
