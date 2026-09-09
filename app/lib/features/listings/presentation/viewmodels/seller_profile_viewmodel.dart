import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/reviews/domain/repositories/review_repository.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/reviews/domain/entities/review_entity.dart';

class SellerProfileViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ListingRepository _listingRepository;
  final ReviewRepository _reviewRepository;

  SellerProfileViewModel({
    required AuthRepository authRepository,
    required ListingRepository listingRepository,
    required ReviewRepository reviewRepository,
  }) : _authRepository = authRepository,
       _listingRepository = listingRepository,
       _reviewRepository = reviewRepository;

  User? _seller;
  User? get seller => _seller;

  List<Listing> _listings = [];
  List<Listing> get listings => _listings;

  List<ReviewEntity> _reviews = [];
  List<ReviewEntity> get reviews => _reviews;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  double get averageRating {
    if (_reviews.isEmpty) return 0.0;
    final sum = _reviews.fold(0, (prev, element) => prev + element.rating);
    return sum / _reviews.length;
  }

  Future<void> loadSellerProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final userResult = await _authRepository.getUserById(userId);

    await userResult.fold(
      (failure) async {
        _error = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (user) async {
        _seller = user;

        // Load listings and reviews in parallel
        final results = await Future.wait([
          _listingRepository.getListingsBySeller(userId),
          _reviewRepository.getUserReviews(userId),
        ]);

        final listingsResult = results[0];
        final reviewsResult = results[1];

        listingsResult.fold(
          (failure) => _error = failure.message,
          (listings) => _listings = listings as List<Listing>,
        );

        reviewsResult.fold(
          (failure) => _error = failure.message,
          (reviews) => _reviews = reviews as List<ReviewEntity>,
        );

        _isLoading = false;
        notifyListeners();
      },
    );
  }
}
