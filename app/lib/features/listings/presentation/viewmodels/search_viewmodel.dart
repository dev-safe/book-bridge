import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/listings/domain/entities/category.dart';
import 'package:book_bridge/features/listings/domain/repositories/listing_repository.dart';
import 'package:book_bridge/features/listings/domain/usecases/search_listings_usecase.dart';

/// State enum for the Search screen.
enum SearchState { initial, loading, success, error, empty }

/// ViewModel for managing search functionality.
///
/// This ViewModel handles searching listings by query and managing
/// search results with debouncing.
class SearchViewModel extends ChangeNotifier {
  final SearchListingsUseCase searchListingsUseCase;
  final ListingRepository repository;
  static const String _recentSearchesKey = 'recent_searches';

  SearchState _searchState = SearchState.initial;
  String? _errorMessage;
  List<Listing> _searchResults = [];
  List<String> _recentSearches = [];
  List<Category> _categories = [];
  String _currentQuery = '';
  Category? _selectedCategory;
  bool _isSearching = false;

  SearchViewModel({
    required this.searchListingsUseCase,
    required this.repository,
  }) {
    loadRecentSearches();
    loadCategories();
  }

  // Getters
  SearchState get searchState => _searchState;
  String? get errorMessage => _errorMessage;
  List<Listing> get searchResults => _searchResults;
  List<String> get recentSearches => _recentSearches;
  List<Category> get categories => _categories;
  String get currentQuery => _currentQuery;
  Category? get selectedCategory => _selectedCategory;
  bool get isSearching => _isSearching;

  /// Loads academic categories.
  Future<void> loadCategories() async {
    final result = await repository.getCategories();
    result.fold(
      (failure) {
        // We can ignore category loading errors or handle them silently
      },
      (categories) {
        _categories = categories;
        notifyListeners();
      },
    );
  }

  /// Loads recent searches from SharedPreferences.
  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    notifyListeners();
  }

  /// Adds a query to recent searches.
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Remove if already exists to move it to top
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);

    // Limit to 10 stored searches
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }

    notifyListeners();
    await _saveRecentSearches();
  }

  /// Removes a specific search term.
  Future<void> removeRecentSearch(String query) async {
    _recentSearches.remove(query);
    notifyListeners();
    await _saveRecentSearches();
  }

  /// Clears all recent searches.
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    notifyListeners();
    await _saveRecentSearches();
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  /// Performs a search with the given query.
  ///
  /// Returns empty list if query is empty.
  Future<void> search(String query) async {
    _currentQuery = query.trim();

    // Clear results if query is empty
    if (_currentQuery.isEmpty) {
      _searchState = SearchState.initial;
      _searchResults = [];
      _isSearching = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    // Add to recent searches
    addRecentSearch(_currentQuery);

    _isSearching = true;
    _searchState = SearchState.loading;
    _errorMessage = null;
    notifyListeners();

    final params = SearchListingsParams(query: _currentQuery);
    final result = await searchListingsUseCase(params);

    result.fold(
      (failure) {
        _searchState = SearchState.error;
        _errorMessage = failure.message;
        _searchResults = [];
        _isSearching = false;
        notifyListeners();
      },
      (listings) {
        if (listings.isEmpty) {
          _searchState = SearchState.empty;
        } else {
          _searchState = SearchState.success;
        }
        _searchResults = listings;
        _isSearching = false;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Clears the current search and results.
  void clearSearch() {
    _currentQuery = '';
    _selectedCategory = null;
    _searchResults = [];
    _searchState = SearchState.initial;
    _errorMessage = null;
    _isSearching = false;
    notifyListeners();
  }

  /// Searches listings by category.
  Future<void> searchByCategory(Category category) async {
    _selectedCategory = category;
    _currentQuery = category.name;
    _isSearching = true;
    _searchState = SearchState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getListings(category: category.name);

    result.fold(
      (failure) {
        _searchState = SearchState.error;
        _errorMessage = failure.message;
        _searchResults = [];
        _isSearching = false;
        notifyListeners();
      },
      (listings) {
        if (listings.isEmpty) {
          _searchState = SearchState.empty;
        } else {
          _searchState = SearchState.success;
        }
        _searchResults = listings;
        _isSearching = false;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Removes a listing by its ID.
  ///
  /// Used to hide broken listings dynamically.
  void removeListingById(String id) {
    _searchResults.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
