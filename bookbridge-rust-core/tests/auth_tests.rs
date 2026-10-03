use axum::{
    body::Body,
    http::{Request, StatusCode},
    middleware,
    routing::get,
    Router,
};
use std::sync::Arc;
use tower::ServiceExt;
use bookbridge_rust_core::{
    auth::require_internal_auth,
    config::AppConfig,
};

#[tokio::test]
async fn test_auth_middleware() {
    let config = Arc::new(AppConfig {
        database_url: "postgres://dummy".to_string(),
        internal_api_secret: "super_secret_key_12345".to_string(),
        fapshi_base_url: "https://sandbox.fapshi.com".to_string(),
        rate_limits: Default::default(),
        supabase_url: "http://127.0.0.1:1".to_string(),
        supabase_anon_key: "test-anon-key".to_string(),
        port: 8080,
    });

    let app = Router::new()
        .route("/test", get(|| async { "ok" }))
        .layer(middleware::from_fn_with_state(
            config.clone(),
            require_internal_auth,
        ));

    // Case 1: Missing Header
    let req = Request::builder()
        .uri("/test")
        .body(Body::empty())
        .unwrap();
    let response = app.clone().oneshot(req).await.unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    // Case 2: Incorrect Header Value
    let req = Request::builder()
        .uri("/test")
        .header("X-Internal-Secret", "wrong_secret")
        .body(Body::empty())
        .unwrap();
    let response = app.clone().oneshot(req).await.unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    // Case 3: Correct Header Value
    let req = Request::builder()
        .uri("/test")
        .header("X-Internal-Secret", "super_secret_key_12345")
        .body(Body::empty())
        .unwrap();
    let response = app.clone().oneshot(req).await.unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}
