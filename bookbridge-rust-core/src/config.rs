use crate::rate_limit::RateLimitSettings;
use std::time::Duration;

#[derive(Clone, Debug)]
pub struct AppConfig {
    pub database_url: String,
    pub internal_api_secret: String,
    pub fapshi_base_url: String,
    pub supabase_url: String,
    pub supabase_anon_key: String,
    pub port: u16,
    pub rate_limits: RateLimitSettings,
}

impl AppConfig {
    pub fn load() -> anyhow::Result<Self> {
        // Load .env file if present
        let _ = dotenvy::dotenv();

        let database_url = std::env::var("DATABASE_URL")
            .map_err(|_| anyhow::anyhow!("DATABASE_URL environment variable is not set"))?;

        let internal_api_secret = std::env::var("INTERNAL_API_SECRET")
            .map_err(|_| anyhow::anyhow!("INTERNAL_API_SECRET environment variable is not set"))?;

        let fapshi_base_url = std::env::var("FAPSHI_BASE_URL")
            .unwrap_or_else(|_| "https://live.fapshi.com".to_string());

        // Used to verify app users' access tokens via Supabase Auth.
        let supabase_url = std::env::var("SUPABASE_URL")
            .map_err(|_| anyhow::anyhow!("SUPABASE_URL environment variable is not set"))?
            .trim_end_matches('/')
            .to_string();

        let supabase_anon_key = std::env::var("SUPABASE_ANON_KEY")
            .map_err(|_| anyhow::anyhow!("SUPABASE_ANON_KEY environment variable is not set"))?;

        let port = std::env::var("PORT")
            .ok()
            .and_then(|p| p.parse().ok())
            .unwrap_or(8080);

        let defaults = RateLimitSettings::default();
        let rate_limits = RateLimitSettings {
            window: Duration::from_secs(env_u64(
                "RATE_LIMIT_WINDOW_SECS",
                defaults.window.as_secs(),
            )?),
            per_ip: env_u32("RATE_LIMIT_PER_IP", defaults.per_ip)?,
            per_user: env_u32("RATE_LIMIT_PER_USER", defaults.per_user)?,
            payment_initiations_per_user: env_u32(
                "RATE_LIMIT_PAYMENT_INITIATIONS_PER_USER",
                defaults.payment_initiations_per_user,
            )?,
        };

        Ok(Self {
            database_url,
            internal_api_secret,
            fapshi_base_url,
            supabase_url,
            supabase_anon_key,
            port,
            rate_limits,
        })
    }
}

/// Reads a positive whole number from the environment, or `default` if unset.
/// A set but invalid value stops startup instead of being silently ignored.
fn env_u64(name: &str, default: u64) -> anyhow::Result<u64> {
    match std::env::var(name) {
        Err(_) => Ok(default),
        Ok(raw) => match raw.trim().parse::<u64>() {
            Ok(value) if value > 0 => Ok(value),
            _ => Err(anyhow::anyhow!("{name} must be a positive whole number")),
        },
    }
}

fn env_u32(name: &str, default: u32) -> anyhow::Result<u32> {
    let value = env_u64(name, u64::from(default))?;
    u32::try_from(value).map_err(|_| anyhow::anyhow!("{name} is too large"))
}
