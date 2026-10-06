//! Listing coordinates are rounded to about 1 km so a seller's precise
//! location is never shared with other users.
//!
//! Runs only when `DATABASE_URL` points at a local/test Postgres loaded with
//! `tests/fixtures/production_schema.sql` plus the migrations; otherwise it
//! prints a skip notice and passes.

use sqlx::PgPool;
use uuid::Uuid;

async fn test_db() -> Option<PgPool> {
    let _ = dotenvy::dotenv();
    let url = match std::env::var("DATABASE_URL") {
        Ok(url)
            if (url.contains("localhost") || url.contains("127.0.0.1"))
                && !url.contains("supabase") =>
        {
            url
        }
        _ => {
            println!("Skipping listing location DB test (needs a local DATABASE_URL)");
            return None;
        }
    };
    match PgPool::connect(&url).await {
        Ok(pool) => Some(pool),
        Err(e) => {
            println!("Skipping listing location DB test (cannot connect: {e})");
            None
        }
    }
}

async fn seller(pool: &PgPool) -> Uuid {
    let id = Uuid::new_v4();
    sqlx::query("INSERT INTO auth.users (id) VALUES ($1)")
        .bind(id)
        .execute(pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO profiles (id, full_name) VALUES ($1, 'Seller')")
        .bind(id)
        .execute(pool)
        .await
        .unwrap();
    id
}

async fn coords(pool: &PgPool, listing: Uuid) -> (Option<f64>, Option<f64>) {
    sqlx::query_as("SELECT latitude, longitude FROM listings WHERE id = $1")
        .bind(listing)
        .fetch_one(pool)
        .await
        .unwrap()
}

#[tokio::test]
async fn listing_location_is_rounded_on_insert_and_update() {
    let Some(pool) = test_db().await else { return };
    let seller = seller(&pool).await;

    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id, latitude, longitude) \
         VALUES ('Book', 'Author', 500, 'good', $1, 3.866734, 11.516529) RETURNING id",
    )
    .bind(seller)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(coords(&pool, listing).await, (Some(3.87), Some(11.52)));

    sqlx::query("UPDATE listings SET latitude = 4.051234, longitude = 9.768765 WHERE id = $1")
        .bind(listing)
        .execute(&pool)
        .await
        .unwrap();
    assert_eq!(coords(&pool, listing).await, (Some(4.05), Some(9.77)));
}

#[tokio::test]
async fn listing_without_location_stays_empty() {
    let Some(pool) = test_db().await else { return };
    let seller = seller(&pool).await;

    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id) \
         VALUES ('Book', 'Author', 500, 'good', $1) RETURNING id",
    )
    .bind(seller)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(coords(&pool, listing).await, (None, None));
}

#[tokio::test]
async fn migration_can_run_again_and_rounds_existing_rows() {
    let Some(pool) = test_db().await else { return };
    let seller = seller(&pool).await;
    let listing: Uuid = sqlx::query_scalar(
        "INSERT INTO listings (title, author, price_fcfa, condition, seller_id) \
         VALUES ('Book', 'Author', 500, 'good', $1) RETURNING id",
    )
    .bind(seller)
    .fetch_one(&pool)
    .await
    .unwrap();
    // Simulate a precise location saved before the trigger existed.
    let mut tx = pool.begin().await.unwrap();
    sqlx::query("ALTER TABLE listings DISABLE TRIGGER trg_coarsen_listing_location")
        .execute(&mut *tx)
        .await
        .unwrap();
    sqlx::query("UPDATE listings SET latitude = 5.963211, longitude = 10.159876 WHERE id = $1")
        .bind(listing)
        .execute(&mut *tx)
        .await
        .unwrap();
    sqlx::query("ALTER TABLE listings ENABLE TRIGGER trg_coarsen_listing_location")
        .execute(&mut *tx)
        .await
        .unwrap();
    tx.commit().await.unwrap();

    sqlx::raw_sql(include_str!(
        "../../supabase/migrations/20261020000000_coarse_listing_location.sql"
    ))
    .execute(&pool)
    .await
    .unwrap();

    assert_eq!(coords(&pool, listing).await, (Some(5.96), Some(10.16)));
}
