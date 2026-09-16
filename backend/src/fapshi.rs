use crate::config::Config;
use reqwest::header::{HeaderMap, HeaderValue, CONTENT_TYPE};
use std::time::Duration;
use tracing::error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum FapshiStatus {
    Created,
    Pending,
    Successful,
    Failed,
    Expired,
    #[serde(other)]
    Unknown,
}

#[derive(Debug, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectPayRequest<'a> {
    pub amount: u64,
    pub phone: &'a str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub network: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_id: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub trans_id: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<&'a str>,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectPayResponse {
    pub message: Option<String>,
    #[serde(alias = "transId", alias = "trans_id")]
    pub trans_id: Option<String>,
    pub status: Option<FapshiStatus>,
    #[serde(
        alias = "financialTransId",
        alias = "financial_trans_id",
        alias = "financialTransactionId"
    )]
    pub financial_trans_id: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PaymentStatusResponse {
    #[serde(alias = "transId", alias = "trans_id")]
    pub trans_id: Option<String>,
    pub status: FapshiStatus,
    pub amount: Option<f64>,
    pub revenue: Option<f64>,
    pub payer_name: Option<String>,
    pub email: Option<String>,
    pub redirect_url: Option<String>,
    pub external_id: Option<String>,
    pub user_id: Option<String>,
    pub message: Option<String>,
}

#[derive(Debug, Clone)]
pub struct Fapshi {
    client: reqwest::Client,
    base_url: String,
    api_user: String,
    api_key: String,
    pub sandbox: bool,
}

#[connectrpc::async_trait]
pub trait PaymentGateway: Send + Sync {
    async fn direct_pay<'a>(
        &self,
        payload: &DirectPayRequest<'a>,
    ) -> Result<DirectPayResponse, String>;

    async fn get_payment_status(
        &self,
        fapshi_trans_id: &str,
    ) -> Result<PaymentStatusResponse, String>;
}

#[connectrpc::async_trait]
impl PaymentGateway for Fapshi {
    async fn direct_pay<'a>(
        &self,
        payload: &DirectPayRequest<'a>,
    ) -> Result<DirectPayResponse, String> {
        Fapshi::direct_pay(self, payload).await
    }

    async fn get_payment_status(
        &self,
        fapshi_trans_id: &str,
    ) -> Result<PaymentStatusResponse, String> {
        Fapshi::get_payment_status(self, fapshi_trans_id).await
    }
}

impl Fapshi {
    pub fn new(config: &Config) -> Self {
        let base_url = if config.fapshi_sandbox {
            "https://sandbox.fapshi.com".to_string()
        } else {
            config.fapshi_base_url.clone()
        };

        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .expect("Failed to build reqwest Client for Fapshi");

        Self {
            client,
            base_url,
            api_user: config.fapshi_api_user.clone().unwrap_or_default(),
            api_key: config.fapshi_api_key.clone().unwrap_or_default(),
            sandbox: config.fapshi_sandbox,
        }
    }

    fn auth_headers(&self) -> HeaderMap {
        let mut headers = HeaderMap::new();
        if let Ok(val) = HeaderValue::from_str(&self.api_user) {
            headers.insert("apiuser", val);
        }
        if let Ok(val) = HeaderValue::from_str(&self.api_key) {
            headers.insert("apikey", val);
        }
        headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        headers
    }

    pub async fn direct_pay<'a>(
        &self,
        payload: &DirectPayRequest<'a>,
    ) -> Result<DirectPayResponse, String> {
        let url = format!("{}/direct-pay", self.base_url);
        let resp = self
            .client
            .post(&url)
            .headers(self.auth_headers())
            .json(payload)
            .send()
            .await
            .map_err(|e| format!("Failed to send direct-pay request: {e}"))?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            error!(%status, %body, "Fapshi direct-pay failed");
            return Err(format!("Fapshi returned error {status}: {body}"));
        }

        resp.json::<DirectPayResponse>()
            .await
            .map_err(|e| format!("Failed to parse direct-pay response: {e}"))
    }

    pub async fn get_payment_status(
        &self,
        trans_id: &str,
    ) -> Result<PaymentStatusResponse, String> {
        let url = format!("{}/payment-status/{}", self.base_url, trans_id);
        let resp = self
            .client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .map_err(|e| format!("Failed to fetch payment status: {e}"))?;

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            error!(%status, %body, "Fapshi payment-status check failed");
            return Err(format!("Fapshi payment-status failed {status}: {body}"));
        }

        resp.json::<PaymentStatusResponse>()
            .await
            .map_err(|e| format!("Failed to parse payment-status response: {e}"))
    }
}
