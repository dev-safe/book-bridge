use crate::jwt::{Claims, JWT};
use connectrpc::async_trait;
use connectrpc::error::ConnectError;
use connectrpc::interceptor::{
    Interceptor, Next, NextStream, PayloadStream, StreamRequest, StreamResponse, UnaryRequest,
    UnaryResponse,
};
use connectrpc::response::RequestContext;
use std::sync::Arc;
use uuid::Uuid;

pub trait AuthContextExt {
    fn claims(&self) -> Option<&Claims>;

    fn require_claims(&self) -> Result<&Claims, ConnectError>;

    fn user_id(&self) -> Result<Uuid, ConnectError> {
        self.require_claims().map(|c| c.user_id)
    }

    fn session_id(&self) -> Result<Uuid, ConnectError> {
        self.require_claims().map(|c| c.session_id)
    }
}

impl AuthContextExt for RequestContext {
    fn claims(&self) -> Option<&Claims> {
        self.extensions().get::<Claims>()
    }

    fn require_claims(&self) -> Result<&Claims, ConnectError> {
        self.claims().ok_or_else(|| {
            ConnectError::unauthenticated("missing authenticated user credentials")
        })
    }
}

#[derive(Clone)]
pub struct AuthInterceptor {
    jwt: Arc<JWT>,
}

impl AuthInterceptor {
    pub fn new(secret: impl AsRef<[u8]>) -> Self {
        Self {
            jwt: Arc::new(JWT::new(secret)),
        }
    }

    fn is_public_path(path: &str) -> bool {
        let normalized = path.trim_start_matches('/');
        matches!(
            normalized,
            "bookbridge.v1.AuthService/SignUp"
                | "bookbridge.v1.AuthService/SignIn"
                | "bookbridge.v1.AuthService/SignInWithGoogle"
                | "bookbridge.v1.AuthService/RefreshSession"
                | "bookbridge.v1.BookService/ListCategories"
                | "bookbridge.v1.BookService/ListBooks"
                | "bookbridge.v1.BookService/SearchBooks"
                | "bookbridge.v1.BookService/GetBook"
                | "bookbridge.v1.BookService/ListBooksBySeller"
                | "bookbridge.v1.MeetupLocationService/ListMeetupLocations"
                | "bookbridge.v1.StatsService/GetPlatformStats"
                | "bookbridge.v1.UserService/GetUser"
                | "bookbridge.v1.ReviewService/ListReviews"
        )
    }

    fn authenticate(&self, ctx: &mut RequestContext) -> Result<(), ConnectError> {
        let path = ctx.path().unwrap_or("");

        if Self::is_public_path(path) {
            if let Some(token) = extract_token(ctx) {
                if let Ok(claims) = self.jwt.decode(&token) {
                    ctx.extensions_mut().insert(claims);
                }
            }
            return Ok(());
        }

        let token = extract_token(ctx).ok_or_else(|| {
            ConnectError::unauthenticated("missing authorization token in request headers")
        })?;

        let claims = self.jwt.decode(&token).map_err(|err| {
            tracing::warn!(%err, "Rejected request with invalid authorization token");
            ConnectError::unauthenticated("invalid or expired authorization token")
        })?;

        ctx.extensions_mut().insert(claims);
        Ok(())
    }
}

fn extract_token(ctx: &RequestContext) -> Option<String> {
    if let Some(auth_val) = ctx.header("authorization") {
        if let Ok(auth_str) = auth_val.to_str() {
            if let Some(token) = auth_str.strip_prefix("Bearer ") {
                return Some(token.trim().to_string());
            }
            if !auth_str.trim().is_empty() {
                return Some(auth_str.trim().to_string());
            }
        }
    }

    if let Some(jwt_val) = ctx.header("jwt") {
        if let Ok(jwt_str) = jwt_val.to_str() {
            if !jwt_str.trim().is_empty() {
                return Some(jwt_str.trim().to_string());
            }
        }
    }

    None
}

#[async_trait]
impl Interceptor for AuthInterceptor {
    async fn intercept_unary(
        &self,
        mut req: UnaryRequest,
        next: Next<'_>,
    ) -> Result<UnaryResponse, ConnectError> {
        self.authenticate(&mut req.ctx)?;
        next.run(req).await
    }

    async fn intercept_streaming(
        &self,
        mut req: StreamRequest,
        inbound: PayloadStream,
        next: NextStream<'_>,
    ) -> Result<StreamResponse, ConnectError> {
        self.authenticate(&mut req.ctx)?;
        next.run(req, inbound).await
    }
}
