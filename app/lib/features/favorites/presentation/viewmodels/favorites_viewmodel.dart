import 'dart:async';
import 'package:flutter/material.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/favorites/domain/usecases/get_favorites_usecase.dart';
import 'package:book_bridge/features/favorites/domain/usecases/toggle_favorite_usecase.dart';
import 'package:book_bridge/features/favorites/domain/usecases/is_favorite_usecase.dart';

enum FavoritesState { initial, loading, loaded, error }

class FavoritesViewModel extends ChangeNotifier {
  final GetFavoritesUseCase getFavoritesUseCase;
  final ToggleFavoriteUseCase toggleFavoriteUseCase;
  final IsFavoriteUseCase isFavoriteUseCase;
  final AuthRepository authRepository;

  StreamSubscription? _authSubscription;

  FavoritesViewModel({
    required this.getFavoritesUseCase,
    required this.toggleFavoriteUseCase,
    required this.isFavoriteUseCase,
    required this.authRepository,
  }) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = authRepository.authStateChanges.listen((user) {
      if (user != null) {
        loadFavorites(user.id);
      } else {
        _favorites = [];
        _isFavoriteCache.clear();
        _state = FavoritesState.initial;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // State
  FavoritesState _state = FavoritesState.initial;
  List<Listing> _favorites = [];
  String? _errorMessage;
  final Map<String, bool> _isFavoriteCache = {};

  // Getters
  FavoritesState get state => _state;
  List<Listing> get favorites => _favorites;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == FavoritesState.loading;

  /// Loads all favorites for a specific user.
  Future<void> loadFavorites(String userId) async {
    _state = FavoritesState.loading;
    notifyListeners();

    final result = await getFavoritesUseCase(userId);

    result.fold(
      (failure) {
        _state = FavoritesState.error;
        _errorMessage = failure.message;
      },
      (listings) {
        _state = FavoritesState.loaded;
        _favorites = listings;
        // Update cache
        for (final listing in listings) {
          _isFavoriteCache[listing.id] = true;
        }
      },
    );

    notifyListeners();
  }

  /// Toggles favorite status for a listing.
  Future<void> toggleFavorite(String userId, Listing listing) async {
    final listingId = listing.id;
    final isCurrentlyFavorite = _isFavoriteCache[listingId] ?? false;

    // Optimistic update
    if (isCurrentlyFavorite) {
      _favorites.removeWhere((l) => l.id == listingId);
      _isFavoriteCache[listingId] = false;
    } else {
      _favorites.insert(0, listing);
      _isFavoriteCache[listingId] = true;
    }
    notifyListeners();

    final result = await toggleFavoriteUseCase(userId, listingId);

    result.fold(
      (failure) {
        // Rollback optimistic update
        if (isCurrentlyFavorite) {
          _favorites.insert(0, listing);
          _isFavoriteCache[listingId] = true;
        } else {
          _favorites.removeWhere((l) => l.id == listingId);
          _isFavoriteCache[listingId] = false;
        }
        _errorMessage = failure.message;
        notifyListeners();
      },
      (isFavorite) {
        // Sync cache with server response if needed
        if (_isFavoriteCache[listingId] != isFavorite) {
          _isFavoriteCache[listingId] = isFavorite;
          if (isFavorite) {
            if (!_favorites.any((l) => l.id == listingId)) {
              _favorites.insert(0, listing);
            }
          } else {
            _favorites.removeWhere((l) => l.id == listingId);
          }
          notifyListeners();
        }
      },
    );
  }

  /// Checks if a listing is favorited.
  bool isListingFavorite(String listingId) {
    return _isFavoriteCache[listingId] ?? false;
  }

  /// Refreshes favorite status for a single listing from server.
  Future<void> checkFavoriteStatus(String userId, String listingId) async {
    final result = await isFavoriteUseCase(userId, listingId);
    result.fold((_) {}, (isFavorite) {
      if (_isFavoriteCache[listingId] != isFavorite) {
        _isFavoriteCache[listingId] = isFavorite;
        notifyListeners();
      }
    });
  }
}
