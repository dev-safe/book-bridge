import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for searching book listings.
class SearchListingsUseCase
    implements UseCase<List<Listing>, SearchListingsParams> {
  final ListingRepository repository;

  SearchListingsUseCase({required this.repository});

  @override
  Future<Either<Failure, List<Listing>>> call(
    SearchListingsParams params,
  ) async {
    return await repository.searchListings(params.query, limit: params.limit);
  }
}

/// Parameters for searching listings.
class SearchListingsParams {
  final String query;
  final int limit;

  SearchListingsParams({required this.query, this.limit = 50});
}
