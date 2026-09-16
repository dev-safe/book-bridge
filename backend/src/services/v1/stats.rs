use super::proto as p;
use crate::db::Database;
use crate::models::BookStatus;
use crate::schema::{books, users};
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;

pub struct StatsService {
    db: Arc<Database>,
}

impl StatsService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }
}

impl p::StatsService for StatsService {
    async fn get_platform_stats(
        &self,
        _ctx: connectrpc::RequestContext,
        _request: connectrpc::ServiceRequest<'_, p::GetPlatformStatsRequest>,
    ) -> connectrpc::ServiceResult<p::GetPlatformStatsResponse> {
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let circulated_books: i64 = books::table
            .filter(books::status.eq(BookStatus::Sold))
            .count()
            .get_result(&mut conn)
            .unwrap_or(0);

        let total_users: i64 = users::table
            .filter(users::deleted_at.is_null())
            .count()
            .get_result(&mut conn)
            .unwrap_or(0);

        // Average savings estimated at 3500 FCFA per circulated book, 2.7kg CO2 avoided per book
        let money_saved = circulated_books * 3500;
        let co2_avoided = (circulated_books as f64) * 2.7;

        let stats = p::PlatformStats {
            total_books_circulated: circulated_books,
            total_students_reached: total_users,
            total_money_saved_fcfa: money_saved,
            total_co2_avoided_kg: co2_avoided,
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::GetPlatformStatsResponse {
            stats: Some(stats).into(),
            ..Default::default()
        }))
    }
}
