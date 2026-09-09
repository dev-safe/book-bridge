import 'dart:async';
import 'package:flutter/material.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/search_viewmodel.dart';
import 'package:book_bridge/core/presentation/widgets/notification_icon.dart';
import 'package:book_bridge/features/listings/domain/entities/category.dart'
    as entity;
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/widgets/listing_card.dart';

/// Search screen for finding book listings.
///
/// This screen provides a search bar and filters to find books,
/// displaying results in a grid or list format.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, SearchViewModel viewModel) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        viewModel.search(query);
      } else {
        viewModel.clearSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(180),
            child: Container(
              color: AppTheme.scholarBlue,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // Top bar with logo and notifications
                      Row(
                        children: [
                          const Icon(Icons.menu_book, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.appTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const NotificationIcon(color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Search bar
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          // No border needed for white on blue
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.searchHint,
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      viewModel.clearSearch();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                            _onSearchChanged(value, viewModel);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show Categories and Recent Searches only when NOT searching
                  if (viewModel.searchState == SearchState.initial ||
                      (viewModel.searchState == SearchState.success &&
                          _searchController.text.isEmpty)) ...[
                    // Academic Categories
                    Text(
                      AppLocalizations.of(context)!.academicCategories,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (viewModel.categories.isEmpty)
                      Center(
                        child: Text(
                          AppLocalizations.of(context)!.noCategoriesAvailable,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.8,
                            ),
                        itemCount: viewModel.categories.length,
                        itemBuilder: (context, index) {
                          final category = viewModel.categories[index];
                          return _buildCategoryItem(
                            context,
                            category,
                            viewModel,
                          );
                        },
                      ),
                    const SizedBox(height: 32),

                    // Recent Searches Section
                    if (viewModel.recentSearches.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.recentSearches,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              viewModel.clearRecentSearches();
                            },
                            child: Text(
                              AppLocalizations.of(context)!.clearAll,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.lightGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Recent search items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: viewModel.recentSearches.length,
                        itemBuilder: (context, index) {
                          final query = viewModel.recentSearches[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                _searchController.text = query;
                                viewModel.search(query);
                                FocusScope.of(context).unfocus();
                              },
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history,
                                    size: 18,
                                    color: AppTheme.lightGray,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      query,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF9DB9A6),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Color(0xFF9DB9A6),
                                    ),
                                    onPressed: () {
                                      viewModel.removeRecentSearch(query);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],

                  // Loading State
                  if (viewModel.searchState == SearchState.loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),

                  // Error State
                  if (viewModel.searchState == SearchState.error)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          viewModel.errorMessage ??
                              AppLocalizations.of(context)!.anErrorOccurred,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),

                  // Empty State
                  if (viewModel.searchState == SearchState.empty ||
                      (viewModel.searchState == SearchState.success &&
                          viewModel.searchResults.isEmpty &&
                          _searchController.text.isNotEmpty))
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.noResultsFoundFor(_searchController.text),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search results
                  if (viewModel.searchState == SearchState.success &&
                      viewModel.searchResults.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.resultsFoundCount(viewModel.searchResults.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio:
                                    0.6, // Further increased space for text
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: viewModel.searchResults.length,
                          itemBuilder: (context, index) {
                            final listing = viewModel.searchResults[index];
                            final homeViewModel = context
                                .watch<HomeViewModel>();
                            return ListingCard(
                              listing: listing,
                              currentPosition: homeViewModel.currentPosition,
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryItem(
    BuildContext context,
    entity.Category category,
    SearchViewModel viewModel,
  ) {
    return GestureDetector(
      onTap: () {
        viewModel.searchByCategory(category);
        _searchController.text = category.name;
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: viewModel.selectedCategory?.id == category.id
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: viewModel.selectedCategory?.id == category.id ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getLocalizedCategory(context, category.name),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      category.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocalizedCategory(BuildContext context, String categoryName) {
    final l10n = AppLocalizations.of(context)!;
    switch (categoryName) {
      case 'Textbooks':
        return l10n.categoryTextbooks;
      case 'Fiction':
        return l10n.categoryFiction;
      case 'Science':
        return l10n.categoryScience;
      case 'History':
        return l10n.categoryHistory;
      case 'GCE':
        return l10n.categoryGCE;
      case 'Business':
        return l10n.categoryBusiness;
      case 'Technology':
        return l10n.categoryTechnology;
      case 'Arts':
        return l10n.categoryArts;
      case 'Language':
        return l10n.categoryLanguage;
      case 'Mathematics':
        return l10n.categoryMathematics;
      case 'Engineering':
        return l10n.categoryEngineering;
      case 'Medicine':
        return l10n.categoryMedicine;
      default:
        return categoryName;
    }
  }
}
