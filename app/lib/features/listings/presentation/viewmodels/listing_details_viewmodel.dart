import 'package:flutter/material.dart';
import 'package:book_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listing_details_usecase.dart';

/// Represents the different states for listing details.
enum ListingDetailsState { initial, loading, loaded, error }

/// ViewModel for managing listing details state.
class ListingDetailsViewModel extends ChangeNotifier {
  final GetListingDetailsUseCase getListingDetailsUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  // State
  ListingDetailsState _detailsState = ListingDetailsState.initial;
  Listing? _listing;
  String? _errorMessage;
  String? _currentUserId;

  // Getters
  ListingDetailsState get detailsState => _detailsState;
  Listing? get listing => _listing;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _detailsState == ListingDetailsState.loading;
  bool get isOwner => _listing != null && _listing!.sellerId == _currentUserId;

  ListingDetailsViewModel({
    required this.getListingDetailsUseCase,
    required this.getCurrentUserUseCase,
  });

  /// Loads the details for a specific listing.
  Future<void> loadListingDetails(String listingId) async {
    _detailsState = ListingDetailsState.loading;
    _listing = null;
    _errorMessage = null;
    notifyListeners();

    // Get current user for ownership check
    final userResult = await getCurrentUserUseCase();
    userResult.fold(
      (_) => _currentUserId = null,
      (user) => _currentUserId = user.id,
    );

    final params = GetListingDetailsParams(listingId: listingId);
    final result = await getListingDetailsUseCase(params);

    result.fold(
      (failure) {
        _detailsState = ListingDetailsState.error;
        _errorMessage = failure.message;
      },
      (listing) {
        _detailsState = ListingDetailsState.loaded;
        _listing = listing;
        _errorMessage = null;
      },
    );
    notifyListeners();
  }

  /// Clears the error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
