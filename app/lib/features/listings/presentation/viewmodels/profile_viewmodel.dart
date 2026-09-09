import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:book_bridge/features/auth/domain/usecases/update_user_usecase.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_user_listings_usecase.dart';
import 'package:book_bridge/features/listings/domain/usecases/delete_listing_usecase.dart';
import 'package:book_bridge/features/listings/data/datasources/supabase_storage_data_source.dart';

/// State enum for the Profile screen.
enum ProfileState { initial, loading, loaded, error }

/// ViewModel for managing the user profile and their listings.
///
/// This ViewModel handles fetching user information, their listings,
/// and managing listing deletion.
class ProfileViewModel extends ChangeNotifier {
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final GetUserListingsUseCase getUserListingsUseCase;
  final DeleteListingUseCase deleteListingUseCase;
  final UpdateUserUseCase updateUserUseCase;
  final SupabaseStorageDataSource storageDataSource;

  ProfileState _profileState = ProfileState.initial;
  String? _errorMessage;
  User? _currentUser;
  List<Listing> _userListings = [];
  String? _deletingListingId;

  ProfileViewModel({
    required this.getCurrentUserUseCase,
    required this.getUserListingsUseCase,
    required this.deleteListingUseCase,
    required this.updateUserUseCase,
    required this.storageDataSource,
  });

  // Getters
  ProfileState get profileState => _profileState;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;
  List<Listing> get userListings => _userListings;
  bool get isLoading => _profileState == ProfileState.loading;
  bool get isDeleting => _deletingListingId != null;

  /// Loads user profile and their listings.
  Future<void> loadProfile() async {
    _profileState = ProfileState.loading;
    _errorMessage = null;
    notifyListeners();

    final userResult = await getCurrentUserUseCase();

    userResult.fold(
      (failure) {
        _profileState = ProfileState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (user) {
        _currentUser = user;
        _loadUserListings(user.id);
      },
    );
  }

  /// Updates the current user's profile.
  Future<void> updateUser({
    String? fullName,
    String? locality,
    String? whatsappNumber,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'No user to update.';
      _profileState = ProfileState.error;
      notifyListeners();
      return;
    }

    _profileState = ProfileState.loading;
    _errorMessage = null;
    notifyListeners();

    final updatedUser = _currentUser!.copyWith(
      fullName: fullName ?? _currentUser!.fullName,
      locality: locality ?? _currentUser!.locality,
      whatsappNumber: whatsappNumber ?? _currentUser!.whatsappNumber,
      avatarUrl: _currentUser!.avatarUrl,
    );

    final result = await updateUserUseCase(updatedUser);

    result.fold(
      (failure) {
        _profileState = ProfileState.error;
        _errorMessage = failure.message;
      },
      (user) {
        _currentUser = user;
        _profileState = ProfileState.loaded; // Back to loaded state
      },
    );
    notifyListeners();
  }

  /// Loads listings for the current user.
  Future<void> _loadUserListings(String userId) async {
    final params = GetUserListingsParams(sellerId: userId);
    final listingsResult = await getUserListingsUseCase(params);

    listingsResult.fold(
      (failure) {
        _profileState = ProfileState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (listings) {
        _userListings = listings;
        _profileState = ProfileState.loaded;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Deletes a listing.
  Future<void> deleteListing(String listingId) async {
    _deletingListingId = listingId;
    notifyListeners();

    final params = DeleteListingParams(listingId: listingId);
    final result = await deleteListingUseCase(params);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _deletingListingId = null;
        notifyListeners();
      },
      (_) {
        _userListings.removeWhere((listing) => listing.id == listingId);
        _deletingListingId = null;
        notifyListeners();
      },
    );
  }

  /// Removes a listing by its ID.
  ///
  /// Used to hide broken listings dynamically.
  void removeListingById(String id) {
    _userListings.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  /// Uploads and updates the profile picture.
  Future<void> uploadProfilePicture(File imageFile) async {
    if (_currentUser == null) return;

    _profileState = ProfileState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload the image to storage
      final imageUrl = await storageDataSource.uploadProfilePicture(imageFile);

      // 2. Update the user profile in the database
      final updatedUser = _currentUser!.copyWith(avatarUrl: imageUrl);
      final result = await updateUserUseCase(updatedUser);

      result.fold(
        (failure) {
          _profileState = ProfileState.error;
          _errorMessage = failure.message;
        },
        (user) {
          _currentUser = user;
          _profileState = ProfileState.loaded;
        },
      );
    } catch (e) {
      _profileState = ProfileState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}
