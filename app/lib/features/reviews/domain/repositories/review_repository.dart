import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';

abstract class ReviewRepository {
  Future<Either<Failure, void>> createReview(ReviewEntity review);
  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(String userId);
  Future<Either<Failure, bool>> hasReviewed(
    String transactionId,
    String reviewerId,
  );
}
