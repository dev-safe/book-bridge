import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/book_condition.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';

/// Use case for updating an existing listing.
class UpdateListingUseCase implements UseCase<Listing, UpdateListingParams> {
  final ListingRepository repository;

  UpdateListingUseCase(this.repository);

  @override
  Future<Either<Failure, Listing>> call(UpdateListingParams params) async {
    return await repository.updateListing(
      id: params.id,
      title: params.title,
      author: params.author,
      priceFcfa: params.priceFcfa,
      condition: params.condition,
      imageUrl: params.imageUrl,
      description: params.description,
      category: params.category,
      sellerType: params.sellerType,
      isBuyBackEligible: params.isBuyBackEligible,
      stockCount: params.stockCount,
      latitude: params.latitude,
      longitude: params.longitude,
    );
  }
}

class UpdateListingParams extends Equatable {
  final String id;
  final String? title;
  final String? author;
  final int? priceFcfa;
  final BookCondition? condition;
  final String? imageUrl;
  final String? description;
  final String? category;
  final String? sellerType;
  final bool? isBuyBackEligible;
  final int? stockCount;
  final double? latitude;
  final double? longitude;

  const UpdateListingParams({
    required this.id,
    this.title,
    this.author,
    this.priceFcfa,
    this.condition,
    this.imageUrl,
    this.description,
    this.category,
    this.sellerType,
    this.isBuyBackEligible,
    this.stockCount,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    priceFcfa,
    condition,
    imageUrl,
    description,
    category,
    sellerType,
    isBuyBackEligible,
    stockCount,
    latitude,
    longitude,
  ];
}
