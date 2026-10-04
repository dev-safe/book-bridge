use crate::error::AppError;
use sqlx::PgPool;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub struct FapshiClient {
    http: reqwest::Client,
    base_url: String,
}

#[derive(Serialize, Clone)]
pub struct PayoutPayload {
    pub amount: f64,
    pub phone: String,
    pub name: String,
    #[serde(rename = "externalId")]
    pub external_id: String,
    pub message: String,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct PayoutResponse {
    /// Fapshi omits this on success and on most errors; the HTTP status is authoritative.
    #[serde(rename = "statusCode")]
    pub status_code: Option<u16>,
    #[serde(rename = "transId")]
    pub trans_id: Option<String>,
    pub message: Option<String>,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct PollResponse {
    pub status: Option<String>,
    pub state: Option<String>,
    #[serde(rename = "statusCode")]
    pub status_code: Option<u16>,
    pub message: Option<String>,
}

/// Body of a collection request (`POST /direct-pay`).
#[derive(Serialize, Debug, Clone, PartialEq)]
pub struct DirectPayRequest {
    pub amount: i64,
    pub phone: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub medium: Option<String>,
    #[serde(rename = "externalId")]
    pub external_id: String,
    pub message: String,
}

#[derive(Deserialize, Debug)]
struct DirectPayResponse {
    #[serde(rename = "transId")]
    trans_id: Option<String>,
    message: Option<String>,
}

/// The parts of `GET /payment-status/{transId}` the app-facing status endpoint needs.
#[derive(Deserialize, Debug)]
pub struct PaymentStatus {
    pub status: Option<String>,
    #[serde(rename = "externalId")]
    pub external_id: Option<String>,
    pub amount: Option<f64>,
    pub message: Option<String>,
}

const COLLECTION_TIMEOUT: std::time::Duration = std::time::Duration::from_secs(60);

#[derive(Deserialize, Serialize, Debug)]
pub struct FapshiSearchItem {
    #[serde(rename = "transId")]
    pub trans_id: String,
    pub status: String,
    #[serde(rename = "externalId")]
    pub external_id: Option<String>,
}

impl FapshiClient {
    pub fn new(base_url: String) -> Self {
        Self {
            http: reqwest::Client::new(),
            base_url,
        }
    }

    /// Fetches a key from the `app_secrets` table.
    async fn get_secret(pool: &PgPool, key: &str) -> Result<String, AppError> {
        let row: (String,) = sqlx::query_as("SELECT value FROM app_secrets WHERE key = $1")
            .bind(key)
            .fetch_one(pool)
            .await?;
        Ok(row.0)
    }

    /// Clean phone number: remove non-digits and strip leading "237".
    pub fn clean_phone(phone: &str) -> String {
        let mut cleaned: String = phone.chars().filter(|c| c.is_ascii_digit()).collect();
        if cleaned.starts_with("237") && cleaned.len() > 3 {
            cleaned = cleaned[3..].to_string();
        }
        cleaned
    }

    /// Base URL for Fapshi API calls. Live traffic always goes to
    /// `live.fapshi.com`; `api.fapshi.com` serves no API routes and answers
    /// with an HTML 404 page.
    pub fn api_base(&self) -> String {
        if self.base_url.contains("live.fapshi.com") || self.base_url.contains("api.fapshi.com") {
            "https://live.fapshi.com".to_string()
        } else {
            self.base_url.trim_end_matches('/').to_string()
        }
    }

    /// Get payout endpoint.
    pub fn payout_url(&self) -> String {
        format!("{}/payout", self.api_base())
    }

    /// Get status endpoint.
    pub fn status_url(&self, reference: &str) -> String {
        format!("{}/payment-status/{}", self.api_base(), reference)
    }

    /// Get search endpoint.
    pub fn search_url(&self) -> String {
        format!("{}/search", self.api_base())
    }

    /// Get direct-pay (collection) endpoint.
    pub fn direct_pay_url(&self) -> String {
        format!("{}/direct-pay", self.api_base())
    }

    /// Sends a Mobile Money payment prompt to the payer using the collection
    /// account, and returns Fapshi's transId.
    pub async fn direct_pay(
        &self,
        pool: &PgPool,
        request: &DirectPayRequest,
    ) -> Result<String, AppError> {
        let api_user = Self::get_secret(pool, "fapshi_collection_api_user").await?;
        let api_key = Self::get_secret(pool, "fapshi_collection_api_key").await?;

        let res = self
            .http
            .post(self.direct_pay_url())
            .timeout(COLLECTION_TIMEOUT)
            .header("apiuser", &api_user)
            .header("apikey", &api_key)
            .json(request)
            .send()
            .await?;

        let status = res.status().as_u16();
        let body: DirectPayResponse = decode_body(status, res).await?;
        if status != 200 {
            let msg = body.message.unwrap_or_else(|| "Unknown error".to_string());
            return Err(AppError::Fapshi(format!(
                "Fapshi direct-pay error ({status}): {msg}"
            )));
        }
        body.trans_id.ok_or_else(|| {
            AppError::Fapshi("Fapshi direct-pay succeeded but returned no transId".to_string())
        })
    }

    /// Looks up a collection transaction with the collection account.
    pub async fn payment_status(
        &self,
        pool: &PgPool,
        trans_id: &str,
    ) -> Result<PaymentStatus, AppError> {
        let api_user = Self::get_secret(pool, "fapshi_collection_api_user").await?;
        let api_key = Self::get_secret(pool, "fapshi_collection_api_key").await?;

        let res = self
            .http
            .get(self.status_url(trans_id))
            .timeout(COLLECTION_TIMEOUT)
            .header("apiuser", &api_user)
            .header("apikey", &api_key)
            .send()
            .await?;

        let status = res.status().as_u16();
        let body: PaymentStatus = decode_body(status, res).await?;
        if status != 200 {
            let msg = body.message.unwrap_or_else(|| "Unknown error".to_string());
            return Err(AppError::Fapshi(format!(
                "Fapshi payment-status error ({status}): {msg}"
            )));
        }
        Ok(body)
    }

    /// Checks if a payout has already been processed successfully on Fapshi by searching by externalId.
    pub async fn check_existing_payout(
        &self,
        pool: &PgPool,
        external_id: &str,
    ) -> Result<Option<String>, AppError> {
        let items = self.search_by_external_id(pool, external_id).await?;
        Ok(items
            .into_iter()
            .find(|item| {
                let status = item.status.to_uppercase();
                status == "SUCCESSFUL" || status == "SUCCESS"
            })
            .map(|item| item.trans_id))
    }

    /// Returns every disbursement-account transaction whose externalId is
    /// exactly `external_id`, whatever its status.
    pub async fn search_by_external_id(
        &self,
        pool: &PgPool,
        external_id: &str,
    ) -> Result<Vec<FapshiSearchItem>, AppError> {
        let api_user = Self::get_secret(pool, "fapshi_disbursement_api_user").await?;
        let api_key = Self::get_secret(pool, "fapshi_disbursement_api_key").await?;

        let res = self
            .http
            .get(self.search_url())
            .header("apiuser", &api_user)
            .header("apikey", &api_key)
            .query(&[("externalId", external_id)])
            .send()
            .await?;

        let status = res.status().as_u16();
        if status != 200 {
            let body_text = res.text().await.unwrap_or_else(|_| "No body".to_string());
            return Err(AppError::Fapshi(format!(
                "Fapshi search returned status {status}: {body_text}"
            )));
        }
        let items: Vec<FapshiSearchItem> = decode_body(status, res).await?;
        Ok(items
            .into_iter()
            .filter(|item| item.external_id.as_deref() == Some(external_id))
            .collect())
    }

    /// Performs payout via Fapshi and logs to fapshi_audit_logs. `tx_id` is
    /// `None` for payouts not tied to a transaction (unmatched-payment refunds).
    #[allow(clippy::too_many_arguments)]
    pub async fn execute_payout(
        &self,
        pool: &PgPool,
        tx_id: Option<Uuid>,
        amount: f64,
        phone: &str,
        recipient_name: &str,
        external_id: &str,
        message: &str,
    ) -> Result<String, AppError> {
        let api_user = Self::get_secret(pool, "fapshi_disbursement_api_user").await?;
        let api_key = Self::get_secret(pool, "fapshi_disbursement_api_key").await?;

        let cleaned_phone = Self::clean_phone(phone);
        let request_payload = PayoutPayload {
            amount,
            phone: cleaned_phone,
            name: recipient_name.to_string(),
            external_id: external_id.to_string(),
            message: message.to_string(),
        };

        let endpoint = self.payout_url();
        let req_val = serde_json::to_value(&request_payload)?;

        let response = self.http.post(&endpoint)
            .header("Content-Type", "application/json")
            .header("apiuser", &api_user)
            .header("apikey", &api_key)
            .json(&request_payload)
            .send()
            .await;

        let (status_code, resp_val, result) = match response {
            Ok(res) => {
                let status = res.status().as_u16();
                let body_res: Result<PayoutResponse, AppError> = decode_body(status, res).await;
                match body_res {
                    Ok(body) => {
                        let val = serde_json::to_value(&body)?;
                        if status == 200 && body.status_code.is_none_or(|code| code == 200) {
                            if let Some(trans_id) = body.trans_id {
                                (status, val, Ok(trans_id))
                            } else {
                                (status, val, Err(AppError::Fapshi("Payout succeeded but transId was missing".to_string())))
                            }
                        } else {
                            let msg = body.message.unwrap_or_else(|| "Unknown Fapshi payout error".to_string());
                            let code = body.status_code.unwrap_or(status);
                            (status, val, Err(AppError::Fapshi(format!("Fapshi payout error ({code}): {msg}"))))
                        }
                    }
                    Err(e) => (status, serde_json::json!({ "error": e.to_string() }), Err(e)),
                }
            }
            Err(e) => {
                let err_msg = format!("Network error: {}", e);
                (500, serde_json::json!({ "error": err_msg }), Err(AppError::Reqwest(e)))
            }
        };

        // Write to fapshi_audit_logs (gracefully catch errors to prevent double-payouts on db connection drops)
        if let Err(e) = sqlx::query(
            "INSERT INTO fapshi_audit_logs (transaction_id, endpoint, request_payload, response_payload, status_code) VALUES ($1, $2, $3, $4, $5)"
        )
        .bind(tx_id)
        .bind(&endpoint)
        .bind(req_val)
        .bind(resp_val)
        .bind(status_code as i32)
        .execute(pool)
        .await {
            tracing::error!("Failed to write to fapshi_audit_logs during payout: {:?}", e);
        }

        result
    }

    /// Queries Fapshi status for polling stuck transactions.
    pub async fn poll_payment_status(
        &self,
        pool: &PgPool,
        tx_id: Uuid,
        reference: &str,
    ) -> Result<String, AppError> {
        let api_user = Self::get_secret(pool, "fapshi_collection_api_user").await?;
        let api_key = Self::get_secret(pool, "fapshi_collection_api_key").await?;

        let endpoint = self.status_url(reference);

        let response = self.http.get(&endpoint)
            .header("apiuser", &api_user)
            .header("apikey", &api_key)
            .send()
            .await;

        let (status_code, resp_val, result) = match response {
            Ok(res) => {
                let status = res.status().as_u16();
                let body_res: Result<PollResponse, AppError> = decode_body(status, res).await;
                match body_res {
                    Ok(body) => {
                        let val = serde_json::to_value(&body)?;
                        if status == 200 {
                            let fapshi_status = body.status.or(body.state).unwrap_or_default();
                            (status, val, Ok(fapshi_status))
                        } else {
                            let msg = body.message.unwrap_or_else(|| "Unknown status check error".to_string());
                            (status, val, Err(AppError::Fapshi(format!("Fapshi poll error ({}): {}", status, msg))))
                        }
                    }
                    Err(e) => (status, serde_json::json!({ "error": e.to_string() }), Err(e)),
                }
            }
            Err(e) => {
                let err_msg = format!("Network error: {}", e);
                (500, serde_json::json!({ "error": err_msg }), Err(AppError::Reqwest(e)))
            }
        };

        // Write to fapshi_audit_logs for audit trail (gracefully log errors)
        if let Err(e) = sqlx::query(
            "INSERT INTO fapshi_audit_logs (transaction_id, endpoint, request_payload, response_payload, status_code) VALUES ($1, $2, $3, $4, $5)"
        )
        .bind(tx_id)
        .bind(&endpoint)
        .bind(serde_json::Value::Null)
        .bind(resp_val)
        .bind(status_code as i32)
        .execute(pool)
        .await {
            tracing::error!("Failed to write to fapshi_audit_logs during polling: {:?}", e);
        }

        result
    }
}

const BODY_SNIPPET_CHARS: usize = 200;

/// Reads a Fapshi response body and parses it as JSON. On failure the error
/// includes the HTTP status and the start of the body, so unexpected replies
/// (e.g. an HTML error page) are visible in logs and fapshi_audit_logs.
async fn decode_body<T: serde::de::DeserializeOwned>(
    status: u16,
    res: reqwest::Response,
) -> Result<T, AppError> {
    let text = res.text().await?;
    parse_body(status, &text)
}

pub fn parse_body<T: serde::de::DeserializeOwned>(status: u16, text: &str) -> Result<T, AppError> {
    serde_json::from_str(text).map_err(|e| {
        let snippet: String = text.chars().take(BODY_SNIPPET_CHARS).collect();
        AppError::Fapshi(format!(
            "Unexpected Fapshi response (HTTP {status}, {e}): {snippet}"
        ))
    })
}
