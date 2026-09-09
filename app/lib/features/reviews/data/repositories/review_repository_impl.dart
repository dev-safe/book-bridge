import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/reviews/data/datasources/supabase_reviews_data_source.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewsDataSource dataSource;

  ReviewRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, void>> createReview(ReviewEntity review) async {
    try {
      await dataSource.createReview(review);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(
    String userId,
  ) async {
    try {
      final reviews = await dataSource.getUserReviews(userId);
      return Right(reviews);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasReviewed(
    String transactionId,
    String reviewerId,
  ) async {
    try {
      final result = await dataSource.hasReviewed(transactionId, reviewerId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
