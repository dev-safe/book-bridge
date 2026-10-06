import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:book_bridge/core/location/location_access.dart';
import 'package:book_bridge/core/utils/geo_radius.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/get_listings_usecase.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/academic_filters_mixin.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/location_viewmodel.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';
import 'package:book_bridge/features/impact/domain/usecases/get_platform_stats_usecase.dart';

/// Represents the different states for the home feed.
enum HomeState { initial, loading, loaded, error }

/// ViewModel for managing the home feed state and operations.
///
/// This ChangeNotifier manages fetching and displaying listings.
class HomeViewModel extends ChangeNotifier with AcademicFiltersMixin {
  final GetListingsUseCase getListingsUseCase;
  final LocationViewModel locationViewModel;
  final ListingRepository listingRepository;
  final GetPlatformStatsUseCase getPlatformStatsUseCase;
  final LocationAccess locationAccess;

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
  double? _radiusKm;
  bool _shouldScrollToResults = false;
  bool _isOffline = false;
  PlatformStats? _platformStats;
  LocationAccessStatus _locationStatus = LocationAccessStatus.unknown;
  bool _locationPromptDismissed = false;
  bool _disposed = false;

  // Getters
  LocationAccessStatus get locationStatus => _locationStatus;

  /// Whether Home should nudge the user to fix location access.
  bool get showLocationPrompt =>
      locationViewModel.locationEnabled &&
      !_locationPromptDismissed &&
      (_locationStatus == LocationAccessStatus.serviceDisabled ||
          _locationStatus == LocationAccessStatus.denied ||
          _locationStatus == LocationAccessStatus.deniedForever);

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

  /// Selected search radius in km; null means "Any" (no distance filter).
  double? get radiusKm => _radiusKm;

  /// Whether a distance filter is currently narrowing the results.
  bool get isRadiusActive => _radiusKm != null && _currentPosition != null;

  /// Returns filtered listings based on search query and distance radius.
  List<Listing> get filteredListings {
    final withinRadius = _applyRadius(_listings);
    if (_searchQuery.isEmpty) {
      return withinRadius;
    }

    final query = _searchQuery.toLowerCase();
    return withinRadius.where((listing) {
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

    final List<Listing> sortedListings = List.from(_applyRadius(_listings));
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

  @override
  ListingRepository get academicRepository => listingRepository;

  @override
  Future<void> onAcademicFiltersChanged() async {
    if (hasAcademicFilters) _shouldScrollToResults = true;
    await _loadInitialListings();
  }

  HomeViewModel({
    required this.getListingsUseCase,
    required this.locationViewModel,
    required this.listingRepository,
    required this.getPlatformStatsUseCase,
    this.locationAccess = const GeolocatorLocationAccess(),
  }) {
    _loadInitialListings();
    loadAcademicLookups();
    if (locationViewModel.locationEnabled) _fetchLocation();
    // Re-fetch (or clear) location whenever the toggle changes.
    locationViewModel.addListener(_onLocationPreferenceChanged);
  }

  void _onLocationPreferenceChanged() {
    if (locationViewModel.locationEnabled) {
      _fetchLocation();
    } else {
      _currentPosition = null;
      _radiusKm = null;
      _locationStatus = LocationAccessStatus.unknown;
      notifyListeners();
    }
  }

  /// Hides the location prompt for the rest of this app session.
  void dismissLocationPrompt() {
    if (_locationPromptDismissed) return;
    _locationPromptDismissed = true;
    notifyListeners();
  }

  /// Runs the action that fixes the current [locationStatus].
  ///
  /// Settings screens return asynchronously, so [onAppResumed] re-checks
  /// access once the user comes back to the app.
  Future<void> resolveLocationAccess() async {
    try {
      switch (_locationStatus) {
        case LocationAccessStatus.serviceDisabled:
          await locationAccess.openLocationSettings();
        case LocationAccessStatus.deniedForever:
          await locationAccess.openAppSettings();
        case LocationAccessStatus.denied:
          await _fetchLocation();
        case LocationAccessStatus.unknown:
        case LocationAccessStatus.granted:
          break;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error resolving location access: $e');
    }
  }

  /// Re-checks location after the user returns from a settings screen.
  ///
  /// Skips the plain `denied` case so the OS dialog never pops up
  /// unprompted on every resume.
  Future<void> onAppResumed() async {
    if (_locationStatus == LocationAccessStatus.serviceDisabled ||
        _locationStatus == LocationAccessStatus.deniedForever) {
      await _fetchLocation();
    }
  }

  /// Sets the distance radius in km; pass null for "Any".
  void setRadiusKm(double? km) {
    if (_radiusKm == km) return;
    _radiusKm = km;
    notifyListeners();
  }

  @visibleForTesting
  void setCurrentPositionForTesting(Position? position) {
    _currentPosition = position;
    notifyListeners();
  }

  List<Listing> _applyRadius(List<Listing> listings) {
    return filterWithinRadius<Listing>(
      items: listings,
      originLat: _currentPosition?.latitude,
      originLng: _currentPosition?.longitude,
      radiusKm: _radiusKm,
      latOf: (l) => l.latitude,
      lngOf: (l) => l.longitude,
    );
  }

  /// Public method to manually refresh GPS (e.g., pull-to-refresh).
  Future<void> refreshLocation() async {
    if (!locationViewModel.locationEnabled) return;
    await _fetchLocation();
  }

  @override
  void dispose() {
    _disposed = true;
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
      filters: academicFilters,
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
      if (!await locationAccess.isServiceEnabled()) {
        _setLocationStatus(LocationAccessStatus.serviceDisabled);
        return;
      }

      var permission = await locationAccess.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationAccess.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationStatus(LocationAccessStatus.denied);
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLocationStatus(LocationAccessStatus.deniedForever);
        return;
      }

      final position = await locationAccess.currentPosition();
      // The user may have switched location off while GPS was resolving.
      if (_disposed || !locationViewModel.locationEnabled) return;
      _currentPosition = position;
      _locationStatus = LocationAccessStatus.granted;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching location: $e');
    }
  }

  void _setLocationStatus(LocationAccessStatus status) {
    if (_disposed || !locationViewModel.locationEnabled) return;
    if (_locationStatus == status) return;
    _locationStatus = status;
    notifyListeners();
  }
}
