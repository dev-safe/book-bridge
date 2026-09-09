import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';
import 'package:book_bridge/features/impact/domain/usecases/get_platform_stats_usecase.dart';

/// Represents the different states for the home feed.
enum HomeState { initial, loading, loaded, error }

/// ViewModel for managing the home feed state and operations.
///
/// This ChangeNotifier manages fetching and displaying listings.
class HomeViewModel extends ChangeNotifier {
  final GetListingsUseCase getListingsUseCase;
  final LocationViewModel locationViewModel;
  final ListingRepository listingRepository;
  final GetPlatformStatsUseCase getPlatformStatsUseCase;

  // State
  HomeState _homeState = HomeState.initial;
  List<Listing> _listings = [];
  String? _errorMessage;
  int _currentOffset = 0;
  bool _hasMoreListings = true;
  final int _pageSize = 50;
  String? _selectedCategory;
  String _searchQuery = '';
  Position? _currentPosition;
  bool _shouldScrollToResults = false;
  bool _isOffline = false;
  PlatformStats? _platformStats;

  // Getters
  HomeState get homeState => _homeState;
  Position? get currentPosition => _currentPosition;
  List<Listing> get listings => _listings;
  String? get errorMessage => _errorMessage;
  bool get hasMoreListings => _hasMoreListings;
  bool get isLoading => _homeState == HomeState.loading;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get shouldScrollToResults => _shouldScrollToResults;
  PlatformStats? get platformStats => _platformStats;

  /// Whether the current listings are being served from the local SQLite
  /// cache because the device is offline or the remote fetch failed.
  bool get isOffline => _isOffline;

  /// Returns filtered listings based on search query
  List<Listing> get filteredListings {
    if (_searchQuery.isEmpty) {
      return _listings;
    }

    final query = _searchQuery.toLowerCase();
    return _listings.where((listing) {
      return listing.title.toLowerCase().contains(query) ||
          listing.author.toLowerCase().contains(query);
    }).toList();
  }

  /// Returns listings sorted by distance when location is enabled.
  /// Returns an empty list when location is disabled.
  List<Listing> get nearbyListings {
    if (!locationViewModel.locationEnabled || _currentPosition == null) {
      return [];
    }

    final List<Listing> sortedListings = List.from(_listings);
    sortedListings.sort((a, b) {
      if (a.latitude == null || a.longitude == null) return 1;
      if (b.latitude == null || b.longitude == null) return -1;

      final distanceA = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distanceB = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedListings;
  }

  HomeViewModel({
    required this.getListingsUseCase,
    required this.locationViewModel,
    required this.listingRepository,
    required this.getPlatformStatsUseCase,
  }) {
    _loadInitialListings();
    if (locationViewModel.locationEnabled) _fetchLocation();
    // Re-fetch (or clear) location whenever the toggle changes.
    locationViewModel.addListener(_onLocationPreferenceChanged);
  }

  void _onLocationPreferenceChanged() {
    if (locationViewModel.locationEnabled) {
      _fetchLocation();
    } else {
      _currentPosition = null;
      notifyListeners();
    }
  }

  /// Public method to manually refresh GPS (e.g., pull-to-refresh).
  Future<void> refreshLocation() async {
    if (!locationViewModel.locationEnabled) return;
    await _fetchLocation();
  }

  @override
  void dispose() {
    locationViewModel.removeListener(_onLocationPreferenceChanged);
    super.dispose();
  }

  /// Loads the initial set of listings on initialization.
  Future<void> _loadInitialListings() async {
    _homeState = HomeState.loading;
    _currentOffset = 0;
    _listings = [];
    notifyListeners();

    await _fetchListings(offset: 0);
    await _fetchPlatformStats();
  }

  /// Fetches platform-wide social impact stats
  Future<void> _fetchPlatformStats() async {
    final result = await getPlatformStatsUseCase();
    result.fold(
      (failure) => null, // graceful degradation: leave stats null
      (stats) {
        _platformStats = stats;
        notifyListeners();
      },
    );
  }

  /// Fetches listings with optional pagination.
  Future<void> _fetchListings({int offset = 0}) async {
    final params = GetListingsParams(
      status: 'available',
      category: _selectedCategory,
      limit: _pageSize,
      offset: offset,
    );

    final result = await getListingsUseCase(params);

    result.fold(
      (failure) {
        _homeState = HomeState.error;
        _errorMessage = failure.message;
        _hasMoreListings = false;
        _isOffline = false;
      },
      (newListings) {
        // Update offline state from the repository's cache flag.
        _isOffline = listingRepository.isServingFromCache;

        if (offset == 0) {
          // Initial load or refresh
          _listings = newListings;
          _currentOffset = 0;
        } else {
          // Pagination - append to existing
          _listings.addAll(newListings);
          _currentOffset = offset;
        }

        _homeState = HomeState.loaded;
        _errorMessage = null;
        _hasMoreListings = newListings.length == _pageSize;
      },
    );
    notifyListeners();
  }

  /// Refreshes the listings from the beginning.
  Future<void> refreshListings() async {
    await _loadInitialListings();
  }

  /// Loads the next page of listings.
  Future<void> loadMoreListings() async {
    if (!_hasMoreListings || _homeState == HomeState.loading) {
      return;
    }

    _homeState = HomeState.loading;
    notifyListeners();

    await _fetchListings(offset: _currentOffset + _pageSize);
  }

  /// Removes a listing by its ID.
  ///
  /// Used to hide broken listings dynamically.
  void removeListingById(String id) {
    _listings.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  /// Clears the error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets the selected category and reloads listings.
  Future<void> setSelectedCategory(String? category) async {
    _selectedCategory = category;
    if (category != null) {
      _shouldScrollToResults = true;
    }
    await _loadInitialListings();
  }

  /// Consumes the scroll request and resets the flag.
  void consumeScrollRequest() {
    _shouldScrollToResults = false;
  }

  /// Clears the selected category and reloads all listings.
  Future<void> clearCategoryFilter() async {
    _selectedCategory = null;
    await _loadInitialListings();
  }

  /// Sets the search query and filters listings locally.
  void setSearchQuery(String query) {
    _searchQuery = query;
    if (query.isNotEmpty) {
      _shouldScrollToResults = true;
    }
    notifyListeners();
  }

  /// Clears the search query.
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Fetches the user's current location (only when location is enabled).
  Future<void> _fetchLocation() async {
    if (!locationViewModel.locationEnabled) return;
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }
}
