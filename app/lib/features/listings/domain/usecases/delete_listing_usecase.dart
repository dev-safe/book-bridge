import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for deleting a listing.
class DeleteListingUseCase implements UseCase<void, DeleteListingParams> {
  final ListingRepository repository;

  DeleteListingUseCase({required this.repository});

  @override
  Future<Either<Failure, void>> call(DeleteListingParams params) async {
    return await repository.deleteListing(params.listingId);
  }
}

/// Parameters for deleting a listing.
class DeleteListingParams {
  final String listingId;

  DeleteListingParams({required this.listingId});
}
