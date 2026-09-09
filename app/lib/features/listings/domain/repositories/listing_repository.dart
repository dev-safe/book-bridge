import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/category.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';

/// Abstract repository for listing operations.
///
/// This interface defines the contract for all listing-related
/// data operations. The actual implementation is in the data layer.
abstract class ListingRepository {
  /// Whether the most recent [getListings] call was served from the local
  /// SQLite cache (i.e., the device was offline or the remote fetch failed).
  ///
  /// Consumers (e.g., [HomeViewModel]) can read this after a successful
  /// [getListings] call to decide whether to surface an [OfflineBanner].
  bool get isServingFromCache;

  /// Fetches all academic categories.
  Future<Either<Failure, List<Category>>> getCategories();

  /// Fetches all available listings.
  ///
  /// Optionally filters by [status] (defaults to 'available') and [category].
  /// Returns either a [Failure] or a list of [Listing] entities.
  Future<Either<Failure, List<Listing>>> getListings({
    String status = 'available',
    String? category,
    int limit = 50,
    int offset = 0,
  });

  /// Fetches details of a specific listing.
  ///
  /// Returns either a [Failure] or the [Listing] entity.
  /// Returns [NotFoundException] if listing not found.
  Future<Either<Failure, Listing>> getListingDetails(String listingId);

  /// Fetches listings from a specific seller.
  ///
  /// Returns either a [Failure] or a list of [Listing] entities.
  Future<Either<Failure, List<Listing>>> getListingsBySeller(String sellerId);

  /// Searches listings by title or author.
  ///
  /// Returns either a [Failure] or a list of matching [Listing] entities.
  Future<Either<Failure, List<Listing>>> searchListings(
    String query, {
    int limit = 50,
  });

  /// Creates a new listing.
  ///
  /// Returns either a [Failure] or the created [Listing] entity.
  Future<Either<Failure, Listing>> createListing({
    required String title,
    required String author,
    required int priceFcfa,
    required BookCondition condition,
    required String imageUrl,
    String? description,
    String? category,
    String sellerType = 'individual',
    bool isBuyBackEligible = false,
    int stockCount = 1,
    double? latitude,
    double? longitude,
  });

  /// Deletes a listing.
  ///
  /// Returns either a [Failure] or void on success.
  Future<Either<Failure, void>> deleteListing(String listingId);

  /// Updates an existing listing.
  ///
  /// Returns either a [Failure] or the updated [Listing] entity.
  Future<Either<Failure, Listing>> updateListing({
    required String id,
    String? title,
    String? author,
    int? priceFcfa,
    BookCondition? condition,
    String? imageUrl,
    String? description,
    String? category,
    String? sellerType,
    bool? isBuyBackEligible,
    int? stockCount,
    double? latitude,
    double? longitude,
  });

  /// Uploads a book image to storage.
  ///
  /// Returns either a [Failure] or the public URL of the uploaded image.
  Future<Either<Failure, String>> uploadBookImage(File imageFile);

  /// Deletes a book image from storage.
  ///
  /// Returns either a [Failure] or void on success.
  Future<Either<Failure, void>> deleteBookImage(String imagePath);
}
