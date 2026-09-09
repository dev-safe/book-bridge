import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';

class HasReviewedUseCase {
  final ReviewRepository repository;

  HasReviewedUseCase(this.repository);

  Future<Either<Failure, bool>> call(String transactionId, String reviewerId) {
    return repository.hasReviewed(transactionId, reviewerId);
  }
}
