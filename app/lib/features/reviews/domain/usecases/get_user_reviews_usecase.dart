import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';

class GetUserReviewsUseCase {
  final ReviewRepository repository;

  GetUserReviewsUseCase(this.repository);

  Future<Either<Failure, List<ReviewEntity>>> call(String userId) {
    return repository.getUserReviews(userId);
  }
}
