import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for fetching listing details.
class GetListingDetailsUseCase
    extends UseCase<Listing, GetListingDetailsParams> {
  final ListingRepository repository;

  GetListingDetailsUseCase({required this.repository});

  @override
  Future<Either<Failure, Listing>> call(GetListingDetailsParams params) {
    return repository.getListingDetails(params.listingId);
  }
}

/// Parameters for the GetListingDetails use case.
class GetListingDetailsParams {
  final String listingId;

  GetListingDetailsParams({required this.listingId});
}
