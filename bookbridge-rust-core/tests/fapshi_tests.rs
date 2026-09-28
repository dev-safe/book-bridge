use bookbridge_rust_core::error::AppError;
use bookbridge_rust_core::fapshi::{parse_body, FapshiClient, PollResponse};

#[test]
fn live_base_urls_route_to_live_fapshi() {
    for base in ["https://live.fapshi.com", "https://api.fapshi.com", "https://api.fapshi.com/"] {
        let client = FapshiClient::new(base.to_string());
        assert_eq!(client.status_url("ref123"), "https://live.fapshi.com/payment-status/ref123");
        assert_eq!(client.payout_url(), "https://live.fapshi.com/payout");
        assert_eq!(client.search_url(), "https://live.fapshi.com/search");
    }
}

#[test]
fn sandbox_base_url_is_used_as_is() {
    let client = FapshiClient::new("https://sandbox.fapshi.com/".to_string());
    assert_eq!(client.status_url("abc"), "https://sandbox.fapshi.com/payment-status/abc");
    assert_eq!(client.payout_url(), "https://sandbox.fapshi.com/payout");
    assert_eq!(client.search_url(), "https://sandbox.fapshi.com/search");
}

#[test]
fn parse_body_accepts_json() {
    let body: PollResponse = parse_body(200, r#"{"status":"SUCCESSFUL"}"#).unwrap();
    assert_eq!(body.status.as_deref(), Some("SUCCESSFUL"));
}

#[test]
fn parse_body_reports_status_and_snippet_for_html() {
    let html = "<!DOCTYPE html><html><body><pre>Cannot GET /payment-status/x</pre></body></html>";
    let err = parse_body::<PollResponse>(404, html).unwrap_err();
    match err {
        AppError::Fapshi(msg) => {
            assert!(msg.contains("HTTP 404"), "{msg}");
            assert!(msg.contains("Cannot GET /payment-status/x"), "{msg}");
        }
        other => panic!("expected Fapshi error, got {other:?}"),
    }
}

#[test]
fn parse_body_truncates_long_bodies() {
    let long = "x".repeat(5000);
    let err = parse_body::<PollResponse>(502, &long).unwrap_err();
    assert!(err.to_string().len() < 400);
}
