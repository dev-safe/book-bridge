import 'package:book_bridge/core/presentation/widgets/notification_icon.dart';
import 'package:book_bridge/core/presentation/widgets/offline_banner.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:geolocator/geolocator.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/core/constants/categories.dart';
import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:book_bridge/features/listings/presentation/widgets/listing_card.dart';
import 'package:book_bridge/injection_container.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/locale_viewmodel.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/payments/presentation/widgets/payment_bottom_sheet.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/features/impact/presentation/widgets/impact_stats_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPromoPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initial load is handled by the ViewModel
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      context.read<HomeViewModel>().loadMoreListings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<HomeViewModel>(
        builder: (context, viewModel, _) {
          // Handle automatic scroll to results if requested
          if (viewModel.shouldScrollToResults) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  750, // Pointing to the listings section
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                );
                viewModel.consumeScrollRequest();
              }
            });
          }

          return RefreshIndicator.adaptive(
            onRefresh: viewModel.refreshListings,
            child: _buildBody(viewModel),
          );
        },
      ),
    );
  }

  Widget _buildBody(HomeViewModel viewModel) {
    if (viewModel.homeState == HomeState.loading &&
        viewModel.listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildSliverAppBar(),
        if (viewModel.isOffline)
          const SliverToBoxAdapter(child: OfflineBanner()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        _buildPromoBanners(),
        if (viewModel.platformStats != null)
          SliverToBoxAdapter(
            child: ImpactStatsWidget(stats: viewModel.platformStats!),
          ),
        _buildNearbyBooksSection(
          viewModel.nearbyListings,
          viewModel.currentPosition,
        ),
        _buildSectionHeader(AppLocalizations.of(context)!.categories),
        _buildCategoriesSection(),
        if (viewModel.homeState == HomeState.error &&
            viewModel.filteredListings.isEmpty)
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildErrorState(viewModel),
          )
        else if (viewModel.filteredListings.isEmpty)
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildEmptyState(viewModel),
          )
        else ...[
          // Featured listings logic
          if (viewModel.filteredListings.any((l) => l.isFeatured)) ...[
            _buildSectionHeader(AppLocalizations.of(context)!.featuredBooks),
            _buildFeaturedListings(
              viewModel.filteredListings.where((l) => l.isFeatured).toList(),
            ),
          ],
          _buildSectionHeader(AppLocalizations.of(context)!.recentlyAdded),
          _buildListingsGrid(
            viewModel.filteredListings.where((l) => !l.isFeatured).toList(),
            viewModel,
          ),
          if (viewModel.hasMoreListings && viewModel.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildErrorState(HomeViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.somethingWentWrong,
            style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.errorMessage ??
                AppLocalizations.of(context)!.checkConnection,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: viewModel.refreshListings,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.tryAgain),
              ),
              if (viewModel.selectedCategory != null) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: viewModel.clearCategoryFilter,
                  child: Text(AppLocalizations.of(context)!.backToHome),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(HomeViewModel viewModel) {
    final isFiltered = viewModel.selectedCategory != null;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            isFiltered
                ? AppLocalizations.of(
                    context,
                  )!.noBooksIn(viewModel.selectedCategory!)
                : AppLocalizations.of(context)!.noBooksFound,
            style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? AppLocalizations.of(context)!.tryAnotherCategory
                : AppLocalizations.of(context)!.firstListingPrompt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: viewModel.clearCategoryFilter,
              icon: const Icon(Icons.home_rounded),
              label: Text(AppLocalizations.of(context)!.backToHome),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 130, // branding (70) + search bar (60)
      elevation: 4,
      centerTitle: false,
      backgroundColor: theme.appBarTheme.backgroundColor,
      foregroundColor: theme.appBarTheme.foregroundColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            bottom: 60, // Same as search bar section
            left: 16,
            right: 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/logo.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Consumer<LocaleViewModel>(
                builder: (context, localeViewModel, _) {
                  final isEnglish = localeViewModel.locale.languageCode == 'en';
                  return GestureDetector(
                    onTap: () => localeViewModel.toggleLocale(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isEnglish ? '🇺🇸 EN' : '🇫🇷 FR',
                        style: TextStyle(
                          color:
                              theme.appBarTheme.foregroundColor ?? Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              NotificationIcon(color: theme.appBarTheme.foregroundColor),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: (theme.appBarTheme.foregroundColor ?? Colors.white)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.person_outline_rounded,
                    color: theme.appBarTheme.foregroundColor,
                    size: 20,
                  ),
                  onPressed: () => context.push('/profile'),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Consumer<HomeViewModel>(
              builder: (context, viewModel, _) {
                final l10n = AppLocalizations.of(context)!;
                return TextField(
                  controller: _searchController,
                  onChanged: (value) => viewModel.setSearchQuery(value),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: viewModel.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              viewModel.clearSearch();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildNearbyBooksSection(
    List<Listing> listings,
    Position? currentPosition,
  ) {
    if (listings.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.yourNearbyBooks,
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Scroll down to the main grid
                    _scrollController.animateTo(
                      700,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          SizedBox(
            height:
                230, // Adjusted to match 0.72 aspect ratio (160 / 0.72 + spacing)
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              // Show only first 10 for horizontal scroll
              itemCount: listings.length > 10 ? 10 : listings.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 160,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ListingCard(
                      listing: listings[index],
                      currentPosition: currentPosition,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanners() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          SizedBox(
            height: 155, // Further compacted height
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPromoPage = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildNearbyCard(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDonationCard(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              final theme = Theme.of(context);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentPromoPage == index ? 20 : 6,
                decoration: BoxDecoration(
                  color: _currentPromoPage == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNearbyCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            const Color(0xFF7C3AED), // Keep the purple for the premium feel
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.explore_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          // Decorative circles
          Positioned(
            left: 20,
            bottom: 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.nearby,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.bridgeOrange,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        AppLocalizations.of(context)!.discoverBooks,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.growthGreen, Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.growthGreen.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _scrollController.animateTo(
                              320,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.exploreNow,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background glow
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF10B981).withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Layered pins
                      const Positioned(
                        top: 8,
                        left: 8,
                        child: Icon(
                          Icons.location_on,
                          color: Color(0xFF34D399),
                          size: 16,
                        ),
                      ),
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF10B981),
                        size: 32,
                      ),
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(
                          Icons.location_on,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    final user = authViewModel.currentUser;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF97316), // Orange
            Color(0xFFEC4899), // Pink
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          // Floating hearts
          Positioned(
            right: 30,
            top: 20,
            child: Icon(
              Icons.favorite,
              size: 16,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            right: 50,
            top: 50,
            child: Icon(
              Icons.favorite,
              size: 12,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.supportCommunity,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFFEF3C7),
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        AppLocalizations.of(context)!.supportDescription,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => _showDonationOptions(context, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFEC4899),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.giveNow,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      // Stacked books illustration
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 36,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 30,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFFEF3C7),
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      Category(
        name: AppLocalizations.of(context)!.all,
        icon: Icons.grid_view_rounded,
        color: Colors.grey,
      ),
      ...appCategories,
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemBuilder: (context, index) {
            final category = categories[index];
            final name = category.name;
            final icon = category.icon;
            final color = category.color;

            final isSelected = name == AppLocalizations.of(context)!.all
                ? context.watch<HomeViewModel>().selectedCategory == null
                : context.watch<HomeViewModel>().selectedCategory == name;

            return GestureDetector(
              onTap: () {
                if (name == AppLocalizations.of(context)!.all) {
                  context.read<HomeViewModel>().clearCategoryFilter();
                } else {
                  context.read<HomeViewModel>().setSelectedCategory(name);
                }
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: color, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getLocalizedCategory(context, name),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedListings(List<Listing> featuredListings) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 280,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: featuredListings.length,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemBuilder: (context, index) {
            return SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ListingCard(
                  listing: featuredListings[index],
                  currentPosition: context
                      .watch<HomeViewModel>()
                      .currentPosition,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListingsGrid(List<Listing> listings, HomeViewModel viewModel) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final listing = listings[index];
          return ListingCard(
            listing: listing,
            currentPosition: viewModel.currentPosition,
          );
        }, childCount: listings.length),
      ),
    );
  }

  String _getLocalizedCategory(BuildContext context, String? categoryName) {
    if (categoryName == null) return '';
    final l10n = AppLocalizations.of(context)!;
    if (categoryName == l10n.all) return categoryName;

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

  void _showDonationOptions(BuildContext context, user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.selectDonationAmount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAmountButton(context, 100, user),
                    _buildAmountButton(context, 500, user),
                    _buildAmountButton(context, 1000, user),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountButton(BuildContext context, int amount, user) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context); // close amount picker

        final userId = user?.id ?? 'anonymous';
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => ChangeNotifierProvider(
            create: (_) => getIt<PaymentViewModel>(),
            child: PaymentBottomSheet(
              amount: amount,
              title: AppLocalizations.of(context)!.supportBookBridge,
              externalReference: 'donation_${userId}_$timestamp',
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.donationThanks),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A4D8C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        '$amount',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
