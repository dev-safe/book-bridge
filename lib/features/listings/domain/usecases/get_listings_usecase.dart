import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for fetching listings.
class GetListingsUseCase extends UseCase<List<Listing>, GetListingsParams> {
  final ListingRepository repository;

  GetListingsUseCase({required this.repository});

  @override
  Future<Either<Failure, List<Listing>>> call(GetListingsParams params) {
    return repository.getListings(
      status: params.status,
      category: params.category,
      filters: params.filters,
      limit: params.limit,
      offset: params.offset,
    );
  }
}

/// Parameters for the GetListings use case.
class GetListingsParams {
  final String status;
  final String? category;
  final AcademicFilters filters;
  final int limit;
  final int offset;

  GetListingsParams({
    this.status = 'available',
    this.category,
    this.filters = AcademicFilters.none,
    this.limit = 50,
    this.offset = 0,
  });
}
