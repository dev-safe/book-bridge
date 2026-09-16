use super::proto as p;
use crate::models::{self, BookCondition, BookPictureType, BookStatus};
use crate::utils::dt_to_proto;
use connectrpc::error::ConnectError;

pub fn user_to_proto(user: models::User, avatar_url: Option<String>) -> p::User {
    p::User {
        id: user.id.to_string(),
        email: user.email.unwrap_or_default(),
        phone: user.phone,
        first_name: user.first_name,
        last_name: user.last_name,
        avatar_url: avatar_url.unwrap_or_default(),
        rating: user.rating.to_string().parse().unwrap_or(0.0),
        verified: user.verified,
        created_at: Some(dt_to_proto(user.created_at)).into(),
        updated_at: Some(dt_to_proto(user.updated_at)).into(),
        ..Default::default()
    }
}

pub fn user_to_summary(user: models::User, avatar_url: Option<String>) -> p::UserSummary {
    p::UserSummary {
        id: user.id.to_string(),
        first_name: user.first_name,
        last_name: user.last_name,
        avatar_url: avatar_url.unwrap_or_default(),
        rating: user.rating.to_string().parse().unwrap_or(0.0),
        verified: user.verified,
        ..Default::default()
    }
}

pub fn book_condition_to_proto(c: BookCondition) -> p::BookCondition {
    match c {
        BookCondition::New => p::BookCondition::BOOK_CONDITION_NEW,
        BookCondition::LikeNew => p::BookCondition::BOOK_CONDITION_LIKE_NEW,
        BookCondition::Good => p::BookCondition::BOOK_CONDITION_GOOD,
        BookCondition::Fair => p::BookCondition::BOOK_CONDITION_FAIR,
        BookCondition::Poor => p::BookCondition::BOOK_CONDITION_POOR,
    }
}

pub fn book_condition_from_proto(c: p::BookCondition) -> BookCondition {
    match c {
        p::BookCondition::BOOK_CONDITION_NEW => BookCondition::New,
        p::BookCondition::BOOK_CONDITION_LIKE_NEW => BookCondition::LikeNew,
        p::BookCondition::BOOK_CONDITION_GOOD => BookCondition::Good,
        p::BookCondition::BOOK_CONDITION_FAIR => BookCondition::Fair,
        p::BookCondition::BOOK_CONDITION_POOR => BookCondition::Poor,
        _ => BookCondition::Good,
    }
}

pub fn book_status_to_proto(s: BookStatus) -> p::BookStatus {
    match s {
        BookStatus::Available => p::BookStatus::BOOK_STATUS_AVAILABLE,
        BookStatus::Sold => p::BookStatus::BOOK_STATUS_SOLD,
        BookStatus::Reserved => p::BookStatus::BOOK_STATUS_RESERVED,
        BookStatus::Expired => p::BookStatus::BOOK_STATUS_EXPIRED,
        BookStatus::Removed => p::BookStatus::BOOK_STATUS_REMOVED,
    }
}

pub fn book_status_from_proto(s: p::BookStatus) -> BookStatus {
    match s {
        p::BookStatus::BOOK_STATUS_AVAILABLE => BookStatus::Available,
        p::BookStatus::BOOK_STATUS_SOLD => BookStatus::Sold,
        p::BookStatus::BOOK_STATUS_RESERVED => BookStatus::Reserved,
        p::BookStatus::BOOK_STATUS_EXPIRED => BookStatus::Expired,
        p::BookStatus::BOOK_STATUS_REMOVED => BookStatus::Removed,
        _ => BookStatus::Available,
    }
}

pub fn book_picture_type_to_proto(t: BookPictureType) -> p::BookPictureType {
    match t {
        BookPictureType::Front => p::BookPictureType::BOOK_PICTURE_TYPE_FRONT,
        BookPictureType::Back => p::BookPictureType::BOOK_PICTURE_TYPE_BACK,
        BookPictureType::Other => p::BookPictureType::BOOK_PICTURE_TYPE_OTHER,
    }
}

pub fn book_picture_type_from_proto(t: p::BookPictureType) -> BookPictureType {
    match t {
        p::BookPictureType::BOOK_PICTURE_TYPE_FRONT => BookPictureType::Front,
        p::BookPictureType::BOOK_PICTURE_TYPE_BACK => BookPictureType::Back,
        _ => BookPictureType::Other,
    }
}

pub fn lat_lng_to_h3_indices(
    latitude: f64,
    longitude: f64,
) -> Result<(i64, i64, i64, i64, i64), ConnectError> {
    let coord = h3o::LatLng::new(latitude, longitude).map_err(|err| {
        tracing::warn!(%latitude, %longitude, %err, "Invalid geographic coordinates");
        ConnectError::invalid_argument(format!("invalid latitude/longitude coordinates: {err}"))
    })?;

    let h3_3 = u64::from(coord.to_cell(h3o::Resolution::Three)) as i64;
    let h3_4 = u64::from(coord.to_cell(h3o::Resolution::Four)) as i64;
    let h3_5 = u64::from(coord.to_cell(h3o::Resolution::Five)) as i64;
    let h3_6 = u64::from(coord.to_cell(h3o::Resolution::Six)) as i64;
    let h3_7 = u64::from(coord.to_cell(h3o::Resolution::Seven)) as i64;

    Ok((h3_3, h3_4, h3_5, h3_6, h3_7))
}
