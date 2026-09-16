use connectrpc::async_trait;
use connectrpc::error::ConnectError;
use connectrpc::interceptor::{
    Interceptor, Next, NextStream, PayloadStream, StreamRequest, StreamResponse, UnaryRequest,
    UnaryResponse,
};
use std::time::Instant;

#[derive(Debug, Clone, Default)]
pub struct LoggingInterceptor;

impl LoggingInterceptor {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait]
impl Interceptor for LoggingInterceptor {
    async fn intercept_unary(
        &self,
        req: UnaryRequest,
        next: Next<'_>,
    ) -> Result<UnaryResponse, ConnectError> {
        let path = req.ctx.path().unwrap_or("unknown").to_string();
        let protocol = req
            .ctx
            .protocol()
            .map(|p| format!("{p:?}"))
            .unwrap_or_else(|| "unknown".into());
        let peer_addr = req
            .ctx
            .peer_addr()
            .map(|p| p.to_string())
            .unwrap_or_else(|| "-".into());

        let start = Instant::now();
        tracing::debug!(
            target: "connectrpc::request",
            path = %path,
            protocol = %protocol,
            peer = %peer_addr,
            "unary request started"
        );

        let result = next.run(req).await;
        let elapsed = start.elapsed();
        let elapsed_ms = elapsed.as_secs_f64() * 1000.0;

        match &result {
            Ok(_) => {
                tracing::info!(
                    target: "connectrpc::response",
                    path = %path,
                    protocol = %protocol,
                    peer = %peer_addr,
                    duration_ms = %format!("{:.2}ms", elapsed_ms),
                    status = "OK",
                    "unary RPC completed"
                );
            }
            Err(err) => {
                tracing::error!(
                    target: "connectrpc::response",
                    path = %path,
                    protocol = %protocol,
                    peer = %peer_addr,
                    duration_ms = %format!("{:.2}ms", elapsed_ms),
                    code = ?err.code,
                    error = %err.message.as_deref().unwrap_or("no message"),
                    "unary RPC failed"
                );
            }
        }

        result
    }

    async fn intercept_streaming(
        &self,
        req: StreamRequest,
        inbound: PayloadStream,
        next: NextStream<'_>,
    ) -> Result<StreamResponse, ConnectError> {
        let path = req.ctx.path().unwrap_or("unknown").to_string();
        let protocol = req
            .ctx
            .protocol()
            .map(|p| format!("{p:?}"))
            .unwrap_or_else(|| "unknown".into());
        let peer_addr = req
            .ctx
            .peer_addr()
            .map(|p| p.to_string())
            .unwrap_or_else(|| "-".into());

        let start = Instant::now();
        tracing::info!(
            target: "connectrpc::stream",
            path = %path,
            protocol = %protocol,
            peer = %peer_addr,
            "streaming RPC connected"
        );

        let result = next.run(req, inbound).await;
        let elapsed = start.elapsed();
        let elapsed_ms = elapsed.as_secs_f64() * 1000.0;

        match &result {
            Ok(_) => {
                tracing::info!(
                    target: "connectrpc::stream",
                    path = %path,
                    protocol = %protocol,
                    peer = %peer_addr,
                    duration_ms = %format!("{:.2}ms", elapsed_ms),
                    status = "OK",
                    "streaming RPC established"
                );
            }
            Err(err) => {
                tracing::error!(
                    target: "connectrpc::stream",
                    path = %path,
                    protocol = %protocol,
                    peer = %peer_addr,
                    duration_ms = %format!("{:.2}ms", elapsed_ms),
                    code = ?err.code,
                    error = %err.message.as_deref().unwrap_or("no message"),
                    "streaming RPC failed establishment"
                );
            }
        }

        result
    }
}
