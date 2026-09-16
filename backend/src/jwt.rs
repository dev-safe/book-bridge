use jsonwebtoken as jwt;
use serde::{Deserialize, Serialize};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use thiserror::Error;
use uuid::Uuid;

pub const DEFAULT_ACCESS_TOKEN_TTL: Duration = Duration::from_secs(60 * 60 * 24); // 24 hours
pub const DEFAULT_REFRESH_TOKEN_TTL: Duration = Duration::from_secs(60 * 60 * 24 * 30); // 30 days

#[derive(Debug, Error)]
pub enum JwtError {
    #[error("JWT error: {0}")]
    Token(#[from] jwt::errors::Error),
    #[error("System clock error generating timestamp")]
    InvalidTimestamp,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Claims {
    pub sub: String,
    pub user_id: Uuid,
    pub session_id: Uuid,
    pub exp: u64,
    pub iat: u64,
}

impl Claims {
    pub fn new(user_id: Uuid, session_id: Uuid, ttl: Duration) -> Result<Self, JwtError> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|_| JwtError::InvalidTimestamp)?
            .as_secs();

        let exp = now + ttl.as_secs();

        Ok(Self {
            sub: user_id.to_string(),
            user_id,
            session_id,
            exp,
            iat: now,
        })
    }
}

#[derive(Debug, Clone)]
pub struct JWT {
    secret: Vec<u8>,
}

impl JWT {
    pub fn new(secret: impl AsRef<[u8]>) -> Self {
        Self {
            secret: secret.as_ref().to_vec(),
        }
    }

    pub fn encode(&self, claims: &Claims) -> Result<String, JwtError> {
        tracing::trace!(%claims.user_id, "Encoding JWT token");
        let token = jwt::encode(
            &jwt::Header::default(),
            claims,
            &jwt::EncodingKey::from_secret(&self.secret),
        )?;
        Ok(token)
    }

    pub fn decode(&self, token: &str) -> Result<Claims, JwtError> {
        tracing::trace!("Decoding and validating JWT token");
        match jwt::decode::<Claims>(
            token,
            &jwt::DecodingKey::from_secret(&self.secret),
            &jwt::Validation::default(),
        ) {
            Ok(data) => {
                tracing::debug!(user_id = %data.claims.user_id, "JWT token successfully validated");
                Ok(data.claims)
            }
            Err(err) => {
                tracing::warn!(%err, "JWT validation failed");
                Err(JwtError::Token(err))
            }
        }
    }
}
