use crate::config::Config;
use diesel::pg::PgConnection;
use diesel::r2d2::{ConnectionManager, Pool, PoolError, PooledConnection};
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};
use std::time::Duration;

pub type PgPool = Pool<ConnectionManager<PgConnection>>;
pub type PgPooledConnection = PooledConnection<ConnectionManager<PgConnection>>;

pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

const CONNECT_TIMEOUT_SECS: u32 = 10;

pub struct Database {
    pool: PgPool,
}

impl Database {
    pub fn connect(conf: &Config) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        tracing::debug!("Initializing PostgreSQL connection pool");
        let url = with_connect_timeout(&conf.database_url);
        let manager = ConnectionManager::<PgConnection>::new(url);
        let pool = Pool::builder()
            .max_size(20)
            .min_idle(Some(2))
            .connection_timeout(Duration::from_secs(CONNECT_TIMEOUT_SECS as u64))
            .build(manager)
            .map_err(|err| {
                tracing::error!(%err, "Failed to initialize database connection pool");
                err
            })?;

        tracing::info!("PostgreSQL connection pool successfully initialized");
        Ok(Self { pool })
    }

    pub fn get_conn(&self) -> Result<PgPooledConnection, PoolError> {
        tracing::trace!("Acquiring database connection from pool");
        self.pool.get().map_err(|err| {
            tracing::error!(%err, "Failed to checkout database connection from pool");
            err
        })
    }
}

pub fn run_migrations(database_url: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    use diesel::Connection;
    let url = with_connect_timeout(database_url);
    let mut connection = PgConnection::establish(&url)?;
    connection
        .run_pending_migrations(MIGRATIONS)
        .map_err(|err| format!("failed to run embedded migrations: {err}"))?;
    Ok(())
}

fn with_connect_timeout(database_url: &str) -> String {
    if database_url.contains("connect_timeout") {
        return database_url.to_string();
    }
    let separator = if database_url.contains('?') { '&' } else { '?' };
    format!("{database_url}{separator}connect_timeout={CONNECT_TIMEOUT_SECS}")
}
