//! In-memory request rate limiting.
//!
//! Requests from the same client IP are counted before authentication, so
//! token-guessing and floods are cut off before they reach Supabase Auth.
//! Requests from the same signed-in user are counted after authentication,
//! and starting a payment, which sends a mobile-money prompt to a phone, has
//! its own lower per-user limit.
//!
//! Counts use fixed windows held in memory. That is enough for a single
//! Render instance. If the service ever runs on several instances, each
//! instance counts separately and the effective limit is multiplied by the
//! number of instances.

use axum::{
    extract::{Request, State},
    http::HeaderMap,
    middleware::Next,
    response::Response,
};
use std::collections::HashMap;
use std::hash::Hash;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use uuid::Uuid;

use crate::error::AppError;
use crate::AppState;

/// Above this many tracked keys, keys whose window has ended are dropped.
const PRUNE_THRESHOLD: usize = 10_000;

/// Allows `max_requests` per key in each fixed window of `window`.
#[derive(Debug)]
pub struct RateLimiter<K> {
    max_requests: u32,
    window: Duration,
    counters: Mutex<HashMap<K, (Instant, u32)>>,
}

impl<K: Eq + Hash + Clone> RateLimiter<K> {
    pub fn new(max_requests: u32, window: Duration) -> Self {
        Self {
            max_requests,
            window,
            counters: Mutex::new(HashMap::new()),
        }
    }

    /// Counts one request for `key`. Returns how long to wait if it is over
    /// the limit.
    pub fn check(&self, key: &K) -> Result<(), Duration> {
        self.check_at(key, Instant::now())
    }

    /// Same as [`check`](Self::check) with an explicit clock, for tests.
    pub fn check_at(&self, key: &K, now: Instant) -> Result<(), Duration> {
        let mut counters = self.counters.lock().unwrap_or_else(|e| e.into_inner());

        if counters.len() >= PRUNE_THRESHOLD {
            let window = self.window;
            counters.retain(|_, (start, _)| now.duration_since(*start) < window);
        }

        let entry = counters.entry(key.clone()).or_insert((now, 0));
        if now.duration_since(entry.0) >= self.window {
            *entry = (now, 0);
        }
        if entry.1 >= self.max_requests {
            return Err(self.window - now.duration_since(entry.0));
        }
        entry.1 += 1;
        Ok(())
    }

    pub fn tracked_keys(&self) -> usize {
        self.counters
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .len()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RateLimitSettings {
    pub window: Duration,
    pub per_ip: u32,
    pub per_user: u32,
    pub payment_initiations_per_user: u32,
}

impl Default for RateLimitSettings {
    fn default() -> Self {
        Self {
            window: Duration::from_secs(60),
            per_ip: 60,
            per_user: 30,
            payment_initiations_per_user: 5,
        }
    }
}

/// The limiters shared by every request handler.
#[derive(Clone, Debug)]
pub struct RateLimits {
    pub per_ip: Arc<RateLimiter<String>>,
    pub per_user: Arc<RateLimiter<Uuid>>,
    pub payment_initiations: Arc<RateLimiter<Uuid>>,
}

impl RateLimits {
    pub fn new(settings: RateLimitSettings) -> Self {
        Self {
            per_ip: Arc::new(RateLimiter::new(settings.per_ip, settings.window)),
            per_user: Arc::new(RateLimiter::new(settings.per_user, settings.window)),
            payment_initiations: Arc::new(RateLimiter::new(
                settings.payment_initiations_per_user,
                settings.window,
            )),
        }
    }
}

impl Default for RateLimits {
    fn default() -> Self {
        Self::new(RateLimitSettings::default())
    }
}

/// Turns a wait time into the error returned to the client.
pub fn too_many_requests(retry_after: Duration) -> AppError {
    // Round up so clients never retry a moment too early.
    let secs = retry_after.as_secs() + u64::from(retry_after.subsec_nanos() > 0);
    AppError::TooManyRequests {
        retry_after_secs: secs.max(1),
    }
}

/// The client's IP address. On Render the service sits behind Cloudflare,
/// which sets `cf-connecting-ip` and overwrites any value sent by the client.
/// The other headers are fallbacks for other proxies and local runs.
pub fn client_ip(headers: &HeaderMap) -> String {
    let header = |name: &str| {
        headers
            .get(name)
            .and_then(|v| v.to_str().ok())
            .map(str::trim)
            .filter(|v| !v.is_empty())
    };

    header("cf-connecting-ip")
        .or_else(|| header("true-client-ip"))
        .or_else(|| {
            header("x-forwarded-for")
                .and_then(|v| v.split(',').next())
                .map(str::trim)
                .filter(|v| !v.is_empty())
        })
        .unwrap_or("unknown")
        .to_string()
}

/// Middleware that limits requests per client IP.
pub async fn limit_by_ip(
    State(state): State<AppState>,
    request: Request,
    next: Next,
) -> Result<Response, AppError> {
    let ip = client_ip(request.headers());
    if let Err(retry_after) = state.rate_limits.per_ip.check(&ip) {
        tracing::warn!(path = %request.uri().path(), "Rate limit hit for client IP");
        return Err(too_many_requests(retry_after));
    }
    Ok(next.run(request).await)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;

    #[test]
    fn allows_requests_up_to_the_limit_then_reports_the_wait() {
        let limiter = RateLimiter::new(3, Duration::from_secs(60));
        let start = Instant::now();
        for _ in 0..3 {
            assert!(limiter.check_at(&"a", start).is_ok());
        }
        let wait = limiter
            .check_at(&"a", start + Duration::from_secs(20))
            .unwrap_err();
        assert_eq!(wait, Duration::from_secs(40));
    }

    #[test]
    fn a_new_window_resets_the_count() {
        let limiter = RateLimiter::new(1, Duration::from_secs(60));
        let start = Instant::now();
        assert!(limiter.check_at(&"a", start).is_ok());
        assert!(limiter.check_at(&"a", start).is_err());
        assert!(limiter
            .check_at(&"a", start + Duration::from_secs(60))
            .is_ok());
    }

    #[test]
    fn keys_are_counted_separately() {
        let limiter = RateLimiter::new(1, Duration::from_secs(60));
        let now = Instant::now();
        assert!(limiter.check_at(&"a", now).is_ok());
        assert!(limiter.check_at(&"a", now).is_err());
        assert!(limiter.check_at(&"b", now).is_ok());
    }

    #[test]
    fn expired_keys_are_pruned_once_the_map_is_large() {
        let limiter = RateLimiter::new(1, Duration::from_secs(60));
        let start = Instant::now();
        for i in 0..PRUNE_THRESHOLD {
            limiter.check_at(&i, start).unwrap();
        }
        assert_eq!(limiter.tracked_keys(), PRUNE_THRESHOLD);

        limiter
            .check_at(&PRUNE_THRESHOLD, start + Duration::from_secs(61))
            .unwrap();
        assert_eq!(limiter.tracked_keys(), 1);
    }

    #[test]
    fn retry_after_is_rounded_up_to_at_least_one_second() {
        let secs = |d| match too_many_requests(d) {
            AppError::TooManyRequests { retry_after_secs } => retry_after_secs,
            other => panic!("unexpected error: {other:?}"),
        };
        assert_eq!(secs(Duration::from_millis(1)), 1);
        assert_eq!(secs(Duration::ZERO), 1);
        assert_eq!(secs(Duration::from_millis(40_200)), 41);
        assert_eq!(secs(Duration::from_secs(40)), 40);
    }

    fn headers(pairs: &[(&'static str, &'static str)]) -> HeaderMap {
        let mut map = HeaderMap::new();
        for (name, value) in pairs {
            map.insert(*name, HeaderValue::from_static(value));
        }
        map
    }

    #[test]
    fn client_ip_prefers_the_cloudflare_header() {
        let map = headers(&[
            ("x-forwarded-for", "9.9.9.9, 10.0.0.1"),
            ("true-client-ip", "8.8.8.8"),
            ("cf-connecting-ip", "1.2.3.4"),
        ]);
        assert_eq!(client_ip(&map), "1.2.3.4");
    }

    #[test]
    fn client_ip_falls_back_through_the_proxy_headers() {
        let map = headers(&[
            ("x-forwarded-for", "9.9.9.9"),
            ("true-client-ip", "8.8.8.8"),
        ]);
        assert_eq!(client_ip(&map), "8.8.8.8");

        let map = headers(&[("x-forwarded-for", " 9.9.9.9 , 10.0.0.1")]);
        assert_eq!(client_ip(&map), "9.9.9.9");

        assert_eq!(client_ip(&HeaderMap::new()), "unknown");
    }
}
