import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:book_bridge/features/favorites/data/datasources/supabase_favorites_data_source.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final SupabaseFavoritesDataSource dataSource;

  FavoritesRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<Listing>>> getFavorites(String userId) async {
    try {
      final models = await dataSource.getFavorites(userId);
      final entities = models.map((model) => model.toEntity()).toList();
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleFavorite(
    String userId,
    String listingId,
  ) async {
    try {
      final result = await dataSource.toggleFavorite(userId, listingId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isFavorite(
    String userId,
    String listingId,
  ) async {
    try {
      final result = await dataSource.isFavorite(userId, listingId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
