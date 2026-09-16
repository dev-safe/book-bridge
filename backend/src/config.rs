use dotenvy::dotenv;
use std::env;
use std::fmt;

/// Application configuration loaded from environment variables.
#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub jwt_secret: String,
    pub port: u16,
    pub fapshi_api_user: Option<String>,
    pub fapshi_api_key: Option<String>,
    pub fapshi_base_url: String,
    pub fapshi_sandbox: bool,
    pub firebase_project_id: Option<String>,
    pub firebase_service_account_path: Option<String>,
    pub fcm_server_key: Option<String>,
    pub cors_allowed_origins: Vec<String>,
}

impl fmt::Debug for Config {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Config")
            .field("database_url", &"[redacted]")
            .field("jwt_secret", &"[redacted]")
            .field("port", &self.port)
            .field("fapshi_api_user", &self.fapshi_api_user.as_ref().map(|_| "[redacted]"))
            .field("fapshi_api_key", &self.fapshi_api_key.as_ref().map(|_| "[redacted]"))
            .field("fapshi_base_url", &self.fapshi_base_url)
            .field("fapshi_sandbox", &self.fapshi_sandbox)
            .field("firebase_project_id", &self.firebase_project_id)
            .field("cors_allowed_origins", &self.cors_allowed_origins)
            .finish()
    }
}

impl Config {
    pub fn load() -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let _ = dotenv();
        tracing::debug!("Loading application environment configuration");

        let database_url = env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgresql://postgres:postgres@localhost:5432/bookbridge".to_string());
        let jwt_secret = env::var("JWT_SECRET")
            .unwrap_or_else(|_| "development_jwt_secret_must_change_in_production_32bytes".to_string());
        let port: u16 = env::var("PORT")
            .unwrap_or_else(|_| "3040".to_string())
            .parse()
            .unwrap_or(3040);

        let fapshi_api_user = env::var("FAPSHI_API_USER").ok();
        let fapshi_api_key = env::var("FAPSHI_API_KEY").ok();
        let fapshi_base_url = env::var("FAPSHI_BASE_URL")
            .unwrap_or_else(|_| "https://api.fapshi.com".to_string());
        let fapshi_sandbox = env::var("FAPSHI_SANDBOX")
            .map(|v| v == "true" || v == "1")
            .unwrap_or(false);

        let firebase_project_id = env::var("FIREBASE_PROJECT_ID").ok();
        let firebase_service_account_path = env::var("FIREBASE_SERVICE_ACCOUNT_PATH").ok();
        let fcm_server_key = env::var("FCM_SERVER_KEY").ok();

        let cors_allowed_origins = env::var("CORS_ALLOWED_ORIGINS")
            .map(|v| {
                v.split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect()
            })
            .unwrap_or_default();

        Ok(Self {
            database_url,
            jwt_secret,
            port,
            fapshi_api_user,
            fapshi_api_key,
            fapshi_base_url,
            fapshi_sandbox,
            firebase_project_id,
            firebase_service_account_path,
            fcm_server_key,
            cors_allowed_origins,
        })
    }
}
