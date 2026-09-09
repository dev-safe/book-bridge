import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/favorites/presentation/viewmodels/favorites_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/home_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/widgets/listing_card.dart';
import 'package:book_bridge/features/favorites/presentation/widgets/pulse_heart_icon.dart';
import 'package:book_bridge/features/favorites/presentation/widgets/skeleton_listing_card.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favoritesVM = context.read<FavoritesViewModel>();
      if (favoritesVM.state != FavoritesState.loaded) {
        final userId = context.read<AuthViewModel>().currentUser?.id;
        if (userId != null) {
          favoritesVM.loadFavorites(userId);
        }
      }
    });
  }

  Future<void> _onRefresh() async {
    final userId = context.read<AuthViewModel>().currentUser?.id;
    if (userId != null) {
      await context.read<FavoritesViewModel>().loadFavorites(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Consumer2<FavoritesViewModel, AuthViewModel>(
      builder: (context, favoritesViewModel, authViewModel, child) {
        final favorites = favoritesViewModel.favorites;
        final hasFavorites = favorites.isNotEmpty;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 140.0,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      AppLocalizations.of(context)!.myFavorites,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    centerTitle: false,
                    titlePadding: EdgeInsets.only(
                      left: canPop ? 56 : 20,
                      bottom: 16,
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.scholarBlue,
                            AppTheme.scholarBlue.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            bottom: -20,
                            child: Icon(
                              Icons.favorite,
                              size: 150,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          if (hasFavorites && !favoritesViewModel.isLoading)
                            Positioned(
                              left: canPop ? 56 : 20,
                              bottom: 48,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.bridgeOrange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${favorites.length} ${favorites.length == 1 ? "book" : "books"} saved',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppTheme.bridgeOrange,
              child: _buildBody(favoritesViewModel, authViewModel),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    FavoritesViewModel favoritesViewModel,
    AuthViewModel authViewModel,
  ) {
    if (favoritesViewModel.isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonListingCard(),
      );
    }

    if (favoritesViewModel.state == FavoritesState.error) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                favoritesViewModel.errorMessage ??
                    AppLocalizations.of(context)!.anErrorOccurred,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  final userId = authViewModel.currentUser?.id;
                  if (userId != null) {
                    favoritesViewModel.loadFavorites(userId);
                  }
                },
                icon: const Icon(Icons.refresh, size: 20),
                label: Text(AppLocalizations.of(context)!.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.scholarBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final favorites = favoritesViewModel.favorites;

    if (favorites.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PulseHeartIcon(),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.noFavoritesYet,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.favoritesEmptySubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppTheme.scholarBlue, AppTheme.bridgeOrange],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.exploreBooks,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final listing = favorites[index];
        final currentPosition = context.watch<HomeViewModel>().currentPosition;

        return ListingCard(
          key: ValueKey(listing.id),
          listing: listing,
          currentPosition: currentPosition,
        );
      },
    );
  }
}
