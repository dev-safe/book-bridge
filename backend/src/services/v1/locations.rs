use super::proto as p;
use crate::db::Database;
use crate::models::{IndexedLocation, MeetupLocation};
use crate::schema::{indexed_locations, meetup_locations};
use crate::utils::dt_to_proto;
use connectrpc::error::ConnectError;
use diesel::prelude::*;
use std::sync::Arc;
use uuid::Uuid;

pub struct MeetupLocationService {
    db: Arc<Database>,
}

impl MeetupLocationService {
    pub fn new(db: Arc<Database>) -> Self {
        Self { db }
    }
}

impl p::MeetupLocationService for MeetupLocationService {
    async fn list_meetup_locations(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::ListMeetupLocationsRequest>,
    ) -> connectrpc::ServiceResult<p::ListMeetupLocationsResponse> {
        let req = request.to_owned_message();
        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let limit = if req.page_size > 0 && req.page_size <= 100 {
            req.page_size as i64
        } else {
            50
        };

        let items: Vec<(MeetupLocation, IndexedLocation)> = meetup_locations::table
            .inner_join(indexed_locations::table.on(meetup_locations::location_id.eq(indexed_locations::id)))
            .limit(limit)
            .load(&mut conn)
            .unwrap_or_default();

        let proto_locations = items
            .into_iter()
            .map(|(ml, il)| p::MeetupLocation {
                id: ml.id.to_string(),
                name: ml.name,
                description: ml.description.unwrap_or_default(),
                verified: ml.verified,
                location: Some(p::LatLng {
                    latitude: il.latitude,
                    longitude: il.longitude,
                    ..Default::default()
                }).into(),
                created_at: Some(dt_to_proto(ml.created_at)).into(),
                ..Default::default()
            })
            .collect();

        Ok(connectrpc::Response::new(p::ListMeetupLocationsResponse {
            locations: proto_locations,
            next_page_token: String::new(),
            ..Default::default()
        }))
    }

    async fn get_meetup_location(
        &self,
        _ctx: connectrpc::RequestContext,
        request: connectrpc::ServiceRequest<'_, p::GetMeetupLocationRequest>,
    ) -> connectrpc::ServiceResult<p::GetMeetupLocationResponse> {
        let req = request.to_owned_message();
        let location_id = Uuid::parse_str(&req.location_id)
            .map_err(|_| ConnectError::invalid_argument("invalid location ID format"))?;

        let mut conn = self.db.get_conn().map_err(|err| {
            tracing::error!(%err, "DB connection error");
            ConnectError::internal("database connection error")
        })?;

        let (ml, il): (MeetupLocation, IndexedLocation) = meetup_locations::table
            .find(location_id)
            .inner_join(indexed_locations::table.on(meetup_locations::location_id.eq(indexed_locations::id)))
            .first(&mut conn)
            .map_err(|_| ConnectError::not_found("meetup location not found"))?;

        let proto_location = p::MeetupLocation {
            id: ml.id.to_string(),
            name: ml.name,
            description: ml.description.unwrap_or_default(),
            verified: ml.verified,
            location: Some(p::LatLng {
                latitude: il.latitude,
                longitude: il.longitude,
                ..Default::default()
            }).into(),
            created_at: Some(dt_to_proto(ml.created_at)).into(),
            ..Default::default()
        };

        Ok(connectrpc::Response::new(p::GetMeetupLocationResponse {
            location: Some(proto_location).into(),
            ..Default::default()
        }))
    }
}
