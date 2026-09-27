#[derive(Clone, Debug)]
pub struct AppConfig {
    pub database_url: String,
    pub internal_api_secret: String,
    pub fapshi_base_url: String,
    pub supabase_url: String,
    pub supabase_anon_key: String,
    pub port: u16,
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

        Ok(Self {
            database_url,
            internal_api_secret,
            fapshi_base_url,
            supabase_url,
            supabase_anon_key,
            port,
        })
    }
}
