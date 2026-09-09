import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';

abstract class FavoritesRepository {
  Future<Either<Failure, List<Listing>>> getFavorites(String userId);
  Future<Either<Failure, bool>> toggleFavorite(String userId, String listingId);
  Future<Either<Failure, bool>> isFavorite(String userId, String listingId);
}
