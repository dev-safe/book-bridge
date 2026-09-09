import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/listing_details_viewmodel.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/favorites/presentation/viewmodels/favorites_viewmodel.dart';
import 'package:book_bridge/features/payments/presentation/widgets/payment_bottom_sheet.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/injection_container.dart';
import 'package:book_bridge/features/listings/domain/entities/listing.dart';
import 'package:book_bridge/features/reviews/presentation/widgets/seller_rating_badge.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/features/safety/presentation/widgets/meetup_tips_card.dart';

/// Listing details screen showing comprehensive information about a book.
///
/// This screen displays book details, images, seller information, and
/// provides functionality to contact the seller via WhatsApp.
class ListingDetailsScreen extends StatefulWidget {
  final String listingId;

  const ListingDetailsScreen({super.key, required this.listingId});

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Load listing details when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ListingDetailsViewModel>().loadListingDetails(
          widget.listingId,
        );
        final userId = context.read<AuthViewModel>().currentUser?.id;
        if (userId != null) {
          context.read<FavoritesViewModel>().checkFavoriteStatus(
            userId,
            widget.listingId,
          );
        }
      }
    });
  }

  Future<void> _shareListing() async {
    final viewModel = context.read<ListingDetailsViewModel>();
    final listing = viewModel.listing;

    if (listing == null) return;

    final l10n = AppLocalizations.of(context)!;
    final shareText =
        '''
${l10n.shareTextCheckOut}
📚 ${listing.title} by ${listing.author}
💰 ${l10n.priceFormat(listing.priceFcfa)}
🔍 ${l10n.shareTextCondition}: ${listing.condition.localizedLabel(l10n)}

${l10n.shareTextDownload}
''';

    await Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListingDetailsViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              color: AppTheme.scholarBlue, // Scholar Blue
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          size: 24,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          // Check if we can pop before attempting to do so
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            // If we can't pop, navigate to home using go_router
                            context.go('/home');
                          }
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.bookDetailsTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () => _shareListing(),
                      ),
                      Consumer2<FavoritesViewModel, AuthViewModel>(
                        builder: (context, favoritesVM, authVM, _) {
                          final viewModel = context
                              .read<ListingDetailsViewModel>();
                          final listing = viewModel.listing;
                          if (listing == null) return const SizedBox.shrink();

                          final userId = authVM.currentUser?.id;
                          final isFavorite = favoritesVM.isListingFavorite(
                            listing.id,
                          );

                          return IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.white,
                            ),
                            onPressed: () {
                              if (userId != null) {
                                favoritesVM.toggleFavorite(userId, listing);
                              } else {
                                context.push('/sign-in');
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _buildBody(viewModel),
          bottomNavigationBar: _buildBottomBar(viewModel),
        );
      },
    );
  }

  Widget _buildBody(ListingDetailsViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.detailsState == ListingDetailsState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.failedToLoadListing,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ??
                  AppLocalizations.of(context)!.unknownError,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final listing = viewModel.listing;
    if (listing == null) {
      return Center(child: Text(AppLocalizations.of(context)!.noListingFound));
    }

    return Column(
      children: [
        // Book Cover Image
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: listing.imageUrl.isNotEmpty
                    ? Image.network(
                        listing.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // If image fails to load in details screen, it's likely a broken listing
                          // Inform user and go back
                          Future.microtask(() {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.listingNotAvailableSnackBar,
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              // Check if we can pop before attempting to do so
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                // If we can't pop, navigate to home using go_router
                                if (context.mounted) {
                                  context.go('/home');
                                }
                              }
                            }
                          });
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: Icon(
                          Icons.image_not_supported,
                          size:
                              MediaQuery.of(context).size.height *
                              0.05, // Responsive size
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
              ),
            ),
          ),
        ),

        // Main content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (listing.isBuyBackEligible)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.growthGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.growthGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.recycling, color: AppTheme.growthGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.buyBackEligible,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.growthGreen,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.buyBackDescription,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Title and Author
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (listing.status == 'sold' || listing.isBoosted)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (listing.isBoosted)
                                      _buildBoostedBadge(context),
                                    if (listing.status == 'sold')
                                      _buildSoldBadge(context),
                                  ],
                                ),
                              ),
                            Text(
                              listing.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              listing.author,
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              listing.sellerType == 'individual'
                                  ? AppLocalizations.of(
                                      context,
                                    )!.sellerTypeIndividualDesc
                                  : listing.sellerType == 'bookshop'
                                  ? AppLocalizations.of(
                                      context,
                                    )!.sellerTypeBookshopDesc
                                  : AppLocalizations.of(
                                      context,
                                    )!.sellerTypeAuthorDesc,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface, // Ink Black
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (listing.sellerType != 'individual')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.scholarBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getLocalizedSellerType(
                              context,
                              listing.sellerType,
                            ).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chips / Status
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Price chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.bridgeOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments,
                              size: 20,
                              color: AppTheme.bridgeOrange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.priceFormat(listing.priceFcfa),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.bridgeOrange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Condition chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          listing.condition
                              .localizedLabel(AppLocalizations.of(context)!)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Category chip
                      if (listing.category != null &&
                          listing.category!.isNotEmpty &&
                          listing.category != 'Uncategorized')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            _getLocalizedCategory(
                              context,
                              listing.category!,
                            ).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description / Details
                  Text(
                    AppLocalizations.of(context)!.descriptionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Light gray
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    listing.description.isNotEmpty
                        ? listing.description
                        : AppLocalizations.of(context)!.noDescriptionProvided,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seller Section
                  Text(
                    AppLocalizations.of(context)!.sellerInformationLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Light gray
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () =>
                        context.push('/seller-profile/${listing.sellerId}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child:
                                      listing.sellerAvatarUrl != null &&
                                          listing.sellerAvatarUrl!.isNotEmpty
                                      ? Image.network(
                                          listing.sellerAvatarUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                );
                                              },
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    listing.sellerType ==
                                                            'bookshop'
                                                        ? Icons.store
                                                        : listing.sellerType ==
                                                              'author'
                                                        ? Icons.history_edu
                                                        : Icons.person,
                                                    color: AppTheme.scholarBlue,
                                                  ),
                                        )
                                      : Icon(
                                          listing.sellerType == 'bookshop'
                                              ? Icons.store
                                              : listing.sellerType == 'author'
                                              ? Icons.history_edu
                                              : Icons.person,
                                          color: AppTheme.scholarBlue,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          listing.sellerName ??
                                              AppLocalizations.of(
                                                context,
                                              )!.unknownSeller,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (listing.sellerRating != null) ...[
                                          const SizedBox(width: 8),
                                          SellerRatingBadge(
                                            rating: listing.sellerRating!,
                                            reviewCount:
                                                listing.sellerReviewCount ?? 0,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          listing.sellerLocality ??
                                              AppLocalizations.of(
                                                context,
                                              )!.unknownLocation,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant, // Light gray
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.verified,
                                color: AppTheme.growthGreen, // Primary green
                              ),
                            ],
                          ),
                          if (listing.sellerType != 'individual') ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              listing.sellerType == 'bookshop'
                                  ? AppLocalizations.of(
                                      context,
                                    )!.sellerTypeBookshopPromo
                                  : AppLocalizations.of(
                                      context,
                                    )!.sellerTypeAuthorPromo,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.growthGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const MeetupTipsCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBoostBottomSheet(
    BuildContext context,
    Listing listing,
    ListingDetailsViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => getIt<PaymentViewModel>(),
        child: PaymentBottomSheet(
          amount: 500, // 500 FCFA for 7 days
          title: AppLocalizations.of(context)!.boostListing,
          externalReference:
              'boost_${listing.id}_7_${DateTime.now().millisecondsSinceEpoch}',
          onSuccess: () {
            // Refresh details to show boosted status
            viewModel.loadListingDetails(listing.id);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.boostListingSuccess,
                ),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget? _buildBottomBar(ListingDetailsViewModel viewModel) {
    final listing = viewModel.listing;
    if (listing == null) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Consumer<AuthViewModel>(
        builder: (context, authVM, child) {
          final isOwner = authVM.currentUser?.id == listing.sellerId;

          if (isOwner) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showBoostBottomSheet(context, listing, viewModel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.bridgeOrange, // Warning/Boost Orange
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.rocket_launch, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.boostListing,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.boostListingDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: listing.status == 'available'
                      ? () {
                          // Check if authenticated
                          if (authVM.currentUser == null) {
                            context.push('/sign-in');
                            return;
                          }

                          // Navigate to chat thread
                          context.push(
                            '/chat/${listing.id}',
                            extra: {
                              'otherUserId': listing.sellerId,
                              'otherUserName':
                                  listing.sellerName ??
                                  AppLocalizations.of(context)!.unknownSeller,
                              'listingTitle': listing.title,
                              'listingPrice': listing.priceFcfa,
                            },
                          );
                        }
                      : null, // Disable if sold
                  style: ElevatedButton.styleFrom(
                    backgroundColor: listing.status == 'available'
                        ? AppTheme.scholarBlue
                        : Colors.grey, // Grey color for sold state
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    listing.status == 'available'
                        ? Icons.chat_bubble_outline
                        : Icons.check_circle_outline,
                    size: 20,
                  ),
                  label: Text(
                    listing.status == 'available'
                        ? AppLocalizations.of(context)!.messageSeller
                        : AppLocalizations.of(context)!.sold.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (listing.status == 'available' &&
                  authVM.currentUser != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final buyerId = authVM.currentUser!.id;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ChangeNotifierProvider(
                          create: (_) => getIt<PaymentViewModel>(),
                          child: PaymentBottomSheet(
                            amount: listing.priceFcfa,
                            title: AppLocalizations.of(context)!.buyNow,
                            externalReference:
                                'purchase_${listing.id}_${buyerId}_${DateTime.now().millisecondsSinceEpoch}',
                            onSuccess: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.paymentSuccessful,
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.scholarBlue,
                      side: const BorderSide(
                        color: AppTheme.scholarBlue,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text(
                      AppLocalizations.of(context)!.buyNow,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoostedBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold to Orange
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.boosted.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoldBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.sold.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedSellerType(BuildContext context, String sellerType) {
    final l10n = AppLocalizations.of(context)!;
    switch (sellerType.toLowerCase()) {
      case 'individual':
        return l10n.sellerTypeIndividual;
      case 'bookshop':
        return l10n.sellerTypeBookshop;
      case 'author':
        return l10n.sellerTypeAuthor;
      default:
        return sellerType;
    }
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
