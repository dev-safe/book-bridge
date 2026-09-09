import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for fetching user's listings.
class GetUserListingsUseCase
    implements UseCase<List<Listing>, GetUserListingsParams> {
  final ListingRepository repository;

  GetUserListingsUseCase({required this.repository});

  @override
  Future<Either<Failure, List<Listing>>> call(
    GetUserListingsParams params,
  ) async {
    return await repository.getListingsBySeller(params.sellerId);
  }
}

/// Parameters for getting user listings.
class GetUserListingsParams {
  final String sellerId;

  GetUserListingsParams({required this.sellerId});
}
