import 'package:sqflite/sqflite.dart';
import 'package:book_bridge/features/listings/data/models/listing_model.dart';

/// Cache TTL: 24 hours expressed in milliseconds.
const int _kCacheTtlMs = 24 * 60 * 60 * 1000;

/// Local SQLite data source for cached listings.
///
/// Provides cache-aside operations for [ListingModel]s. Only the fields
/// present in the `cached_listings` schema are persisted; nullable seller-join
/// fields (name, avatar, etc.) are omitted and will be `null` when
/// listings are served from cache — graceful degradation offline.
class LocalListingsDataSource {
  final Database database;

  LocalListingsDataSource({required this.database});

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Upserts a batch of listings into the local cache, stamping the current
  /// Unix timestamp (ms) as [cached_at].
  ///
  /// Uses `INSERT OR REPLACE` so repeated fetches of the same page refresh
  /// existing rows rather than duplicating them.
  Future<void> cacheListings(List<ListingModel> listings) async {
    final batch = database.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final listing in listings) {
      batch.insert('cached_listings', {
        'id': listing.id,
        'title': listing.title,
        'author': listing.author,
        'price_fcfa': listing.priceFcfa,
        'condition': listing.condition.value,
        'image_url': listing.imageUrl,
        'description': listing.description,
        'seller_id': listing.sellerId,
        'status': listing.status,
        'category': listing.category,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns all cached listings, optionally filtered by [category].
  ///
  /// Results are ordered newest-first (by [cached_at]) to mirror the
  /// Supabase ordering used in the remote data source.
  Future<List<ListingModel>> getCachedListings({String? category}) async {
    final List<Map<String, dynamic>> rows;

    if (category != null && category.isNotEmpty) {
      rows = await database.query(
        'cached_listings',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'cached_at DESC',
      );
    } else {
      rows = await database.query('cached_listings', orderBy: 'cached_at DESC');
    }

    return rows.map(ListingModel.fromCacheRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Validity
  // ---------------------------------------------------------------------------

  /// Returns `true` when the cache contains at least one row whose
  /// [cached_at] is within the TTL window.
  Future<bool> isCacheValid({String? category}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _kCacheTtlMs;

    final List<Map<String, dynamic>> rows;
    if (category != null && category.isNotEmpty) {
      rows = await database.query(
        'cached_listings',
        columns: ['cached_at'],
        where: 'cached_at > ? AND category = ?',
        whereArgs: [cutoff, category],
        limit: 1,
      );
    } else {
      rows = await database.query(
        'cached_listings',
        columns: ['cached_at'],
        where: 'cached_at > ?',
        whereArgs: [cutoff],
        limit: 1,
      );
    }

    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  /// Deletes all rows whose [cached_at] is older than the TTL.
  ///
  /// Should be called once on app startup (after the DB is opened) to prevent
  /// the cache from growing unbounded.
  Future<void> clearExpiredCache() async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _kCacheTtlMs;
    await database.delete(
      'cached_listings',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );
  }
}
