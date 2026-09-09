import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/favorites/domain/repositories/favorites_repository.dart';

class IsFavoriteUseCase {
  final FavoritesRepository repository;

  IsFavoriteUseCase(this.repository);

  Future<Either<Failure, bool>> call(String userId, String listingId) async {
    return await repository.isFavorite(userId, listingId);
  }
}
