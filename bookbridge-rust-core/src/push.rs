//! Firebase Cloud Messaging (HTTP v1) client.
//!
//! Authenticates with a Google service account: a self-signed RS256 JWT is
//! exchanged for an OAuth access token, which is cached until shortly before
//! it expires.

use std::collections::HashMap;
use std::fmt;
use std::time::{Duration, Instant};

use jsonwebtoken::{Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tokio::sync::Mutex;

const FCM_SCOPE: &str = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_FCM_BASE_URL: &str = "https://fcm.googleapis.com";
const ANDROID_CHANNEL_ID: &str = "high_importance_channel";
const TOKEN_LIFETIME_SECS: i64 = 3600;
const TOKEN_REFRESH_MARGIN: Duration = Duration::from_secs(60);

#[derive(Deserialize)]
struct ServiceAccount {
    project_id: String,
    client_email: String,
    private_key: String,
    token_uri: String,
}

#[derive(Serialize)]
struct Claims<'a> {
    iss: &'a str,
    scope: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
}

#[derive(Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
}

struct CachedToken {
    value: String,
    refresh_at: Instant,
}

/// One push message.
pub struct PushMessage<'a> {
    pub token: &'a str,
    pub title: &'a str,
    pub body: &'a str,
    pub kind: &'a str,
    pub data: Option<&'a Value>,
}

/// Why a send failed.
#[derive(Debug, PartialEq, Eq)]
pub enum SendError {
    /// The device token is no longer valid and should be forgotten.
    InvalidToken(String),
    /// Anything else; the send may be retried.
    Failed(String),
}

impl fmt::Display for SendError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SendError::InvalidToken(m) => write!(f, "invalid_token: {m}"),
            SendError::Failed(m) => f.write_str(m),
        }
    }
}

pub struct FcmClient {
    http: reqwest::Client,
    project_id: String,
    client_email: String,
    key: EncodingKey,
    token_uri: String,
    fcm_base_url: String,
    cached: Mutex<Option<CachedToken>>,
}

// Never print the key material.
impl fmt::Debug for FcmClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("FcmClient")
            .field("project_id", &self.project_id)
            .finish_non_exhaustive()
    }
}

impl FcmClient {
    /// Builds a client from the service-account JSON downloaded from the
    /// Firebase console.
    pub fn from_service_account_json(json: &str) -> anyhow::Result<Self> {
        let sa: ServiceAccount = serde_json::from_str(json)
            .map_err(|e| anyhow::anyhow!("invalid FCM service account JSON: {e}"))?;
        let key = EncodingKey::from_rsa_pem(sa.private_key.as_bytes())
            .map_err(|e| anyhow::anyhow!("invalid FCM service account private key: {e}"))?;
        Ok(Self {
            http: reqwest::Client::builder()
                .timeout(Duration::from_secs(15))
                .build()?,
            project_id: sa.project_id,
            client_email: sa.client_email,
            key,
            token_uri: sa.token_uri,
            fcm_base_url: DEFAULT_FCM_BASE_URL.to_string(),
            cached: Mutex::new(None),
        })
    }

    /// Points the client at a different FCM host (tests).
    pub fn with_fcm_base_url(mut self, url: impl Into<String>) -> Self {
        self.fcm_base_url = url.into();
        self
    }

    pub fn project_id(&self) -> &str {
        &self.project_id
    }

    async fn access_token(&self) -> Result<String, SendError> {
        let mut cached = self.cached.lock().await;
        if let Some(t) = cached.as_ref() {
            if Instant::now() < t.refresh_at {
                return Ok(t.value.clone());
            }
        }

        let now = chrono::Utc::now().timestamp();
        let claims = Claims {
            iss: &self.client_email,
            scope: FCM_SCOPE,
            aud: &self.token_uri,
            iat: now,
            exp: now + TOKEN_LIFETIME_SECS,
        };
        let assertion = jsonwebtoken::encode(&Header::new(Algorithm::RS256), &claims, &self.key)
            .map_err(|e| SendError::Failed(format!("jwt signing failed: {e}")))?;

        let resp = self
            .http
            .post(&self.token_uri)
            .form(&[
                ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
                ("assertion", assertion.as_str()),
            ])
            .send()
            .await
            .map_err(|e| SendError::Failed(format!("oauth request failed: {e}")))?;
        let status = resp.status();
        if !status.is_success() {
            let body = resp.text().await.unwrap_or_default();
            return Err(SendError::Failed(format!(
                "oauth token request returned HTTP {status}: {}",
                truncate(&body)
            )));
        }
        let token: TokenResponse = resp
            .json()
            .await
            .map_err(|e| SendError::Failed(format!("oauth response unreadable: {e}")))?;

        let lifetime = Duration::from_secs(token.expires_in).saturating_sub(TOKEN_REFRESH_MARGIN);
        *cached = Some(CachedToken {
            value: token.access_token.clone(),
            refresh_at: Instant::now() + lifetime,
        });
        Ok(token.access_token)
    }

    /// Sends one message and returns the FCM message name.
    pub async fn send(&self, msg: &PushMessage<'_>) -> Result<String, SendError> {
        let access_token = self.access_token().await?;
        let url = format!(
            "{}/v1/projects/{}/messages:send",
            self.fcm_base_url.trim_end_matches('/'),
            self.project_id
        );

        let resp = self
            .http
            .post(&url)
            .bearer_auth(access_token)
            .json(&build_message(msg))
            .send()
            .await
            .map_err(|e| SendError::Failed(format!("fcm request failed: {e}")))?;

        let status = resp.status();
        let body: Value = resp.json().await.unwrap_or(Value::Null);
        if status.is_success() {
            return Ok(body
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string());
        }

        let message = body
            .pointer("/error/message")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        let detail = format!("fcm returned HTTP {status}: {}", truncate(&message));
        if is_invalid_token(status, &body) {
            return Err(SendError::InvalidToken(detail));
        }
        if status == reqwest::StatusCode::UNAUTHORIZED {
            // Access token rejected; drop it so the next call re-authenticates.
            *self.cached.lock().await = None;
        }
        Err(SendError::Failed(detail))
    }
}

fn build_message(msg: &PushMessage<'_>) -> Value {
    // FCM data values must be strings.
    let mut data: HashMap<String, String> = HashMap::new();
    if let Some(Value::Object(map)) = msg.data {
        for (k, v) in map {
            let s = match v {
                Value::String(s) => s.clone(),
                Value::Null => continue,
                other => other.to_string(),
            };
            data.insert(k.clone(), s);
        }
    }
    data.insert("type".to_string(), msg.kind.to_string());

    json!({
        "message": {
            "token": msg.token,
            "notification": { "title": msg.title, "body": msg.body },
            "data": data,
            "android": {
                "priority": "high",
                "notification": { "channel_id": ANDROID_CHANNEL_ID }
            }
        }
    })
}

/// FCM reports a dead registration token as 404 / UNREGISTERED, or as an
/// INVALID_ARGUMENT whose message names the registration token.
fn is_invalid_token(status: reqwest::StatusCode, body: &Value) -> bool {
    let fcm_code = body
        .pointer("/error/details")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|d| d.get("errorCode").and_then(Value::as_str))
        .next();
    if fcm_code == Some("UNREGISTERED") || status == reqwest::StatusCode::NOT_FOUND {
        return true;
    }
    let err_status = body.pointer("/error/status").and_then(Value::as_str);
    let message = body
        .pointer("/error/message")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_ascii_lowercase();
    (fcm_code == Some("INVALID_ARGUMENT") || err_status == Some("INVALID_ARGUMENT"))
        && message.contains("registration token")
}

fn truncate(s: &str) -> String {
    s.chars().take(200).collect()
}

/// Push state carried in `AppState`. `client` is `None` when
/// `FCM_SERVICE_ACCOUNT_JSON` is not configured.
#[derive(Clone, Default, Debug)]
pub struct PushService {
    pub client: Option<std::sync::Arc<FcmClient>>,
    pub dispatch_lock: std::sync::Arc<Mutex<()>>,
}

impl PushService {
    pub fn new(client: Option<FcmClient>) -> Self {
        Self {
            client: client.map(std::sync::Arc::new),
            dispatch_lock: Default::default(),
        }
    }

    /// Reads `FCM_SERVICE_ACCOUNT_JSON`. A missing or invalid value disables
    /// push delivery with a warning rather than stopping the service.
    pub fn from_env() -> Self {
        let Ok(raw) = std::env::var("FCM_SERVICE_ACCOUNT_JSON") else {
            tracing::warn!("FCM_SERVICE_ACCOUNT_JSON not set; push notifications disabled");
            return Self::default();
        };
        match FcmClient::from_service_account_json(&raw) {
            Ok(client) => {
                tracing::info!(project_id = client.project_id(), "FCM push enabled");
                Self::new(Some(client))
            }
            Err(e) => {
                tracing::warn!(error = %e, "Invalid FCM_SERVICE_ACCOUNT_JSON; push notifications disabled");
                Self::default()
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn data_values_are_stringified_and_type_is_set() {
        let data = json!({"listing_id": "abc", "count": 3, "skip": null});
        let msg = PushMessage {
            token: "t",
            title: "Hi",
            body: "There",
            kind: "new_inquiry",
            data: Some(&data),
        };
        let v = build_message(&msg);
        assert_eq!(v["message"]["data"]["listing_id"], "abc");
        assert_eq!(v["message"]["data"]["count"], "3");
        assert_eq!(v["message"]["data"]["type"], "new_inquiry");
        assert!(v["message"]["data"].get("skip").is_none());
        assert_eq!(
            v["message"]["android"]["notification"]["channel_id"],
            ANDROID_CHANNEL_ID
        );
    }

    #[test]
    fn invalid_token_detection() {
        let unregistered = json!({"error": {"status": "NOT_FOUND", "message": "Requested entity was not found.",
            "details": [{"errorCode": "UNREGISTERED"}]}});
        assert!(is_invalid_token(
            reqwest::StatusCode::NOT_FOUND,
            &unregistered
        ));

        let bad_token = json!({"error": {"status": "INVALID_ARGUMENT",
            "message": "The registration token is not a valid FCM registration token"}});
        assert!(is_invalid_token(
            reqwest::StatusCode::BAD_REQUEST,
            &bad_token
        ));

        let bad_payload =
            json!({"error": {"status": "INVALID_ARGUMENT", "message": "Invalid JSON payload"}});
        assert!(!is_invalid_token(
            reqwest::StatusCode::BAD_REQUEST,
            &bad_payload
        ));

        let unavailable = json!({"error": {"status": "UNAVAILABLE", "message": "try later"}});
        assert!(!is_invalid_token(
            reqwest::StatusCode::SERVICE_UNAVAILABLE,
            &unavailable
        ));
    }
}
