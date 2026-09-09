import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/seller_profile_viewmodel.dart';
import 'package:book_bridge/features/listings/presentation/widgets/listing_card.dart';
import 'package:book_bridge/features/reviews/presentation/widgets/seller_rating_badge.dart';
import 'package:book_bridge/features/reviews/presentation/widgets/seller_trust_card.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

class SellerProfileScreen extends StatefulWidget {
  final String userId;

  const SellerProfileScreen({super.key, required this.userId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SellerProfileViewModel>().loadSellerProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SellerProfileViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(viewModel.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.loadSellerProfile(widget.userId),
                    child: Text(AppLocalizations.of(context)!.tryAgain),
                  ),
                ],
              ),
            );
          }

          final seller = viewModel.seller;
          if (seller == null) {
            return const Center(child: Text('Seller not found'));
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(
                context,
                seller,
                viewModel.averageRating,
                viewModel.reviews.length,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SellerTrustCard(
                        seller: seller,
                        reviews: viewModel.reviews,
                      ),
                      const SizedBox(height: 16),
                      _buildStatsRow(context, viewModel),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)!.recentListings,
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (viewModel.listings.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: Text('No active listings')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ListingCard(listing: viewModel.listings[index]);
                    }, childCount: viewModel.listings.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    seller,
    double rating,
    int reviewCount,
  ) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              CircleAvatar(
                radius: 45,
                backgroundImage: seller.avatarUrl != null
                    ? NetworkImage(seller.avatarUrl!)
                    : null,
                child: seller.avatarUrl == null
                    ? const Icon(Icons.person, size: 45)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                seller.fullName ?? 'Unknown Seller',
                style: GoogleFonts.lato(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    seller.locality ?? 'Cameroon',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SellerRatingBadge(rating: rating, reviewCount: reviewCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    SellerProfileViewModel viewModel,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          viewModel.listings.length.toString(),
          'Listings',
          Icons.book,
        ),
        _buildStatItem(
          viewModel.reviews.length.toString(),
          'Reviews',
          Icons.star_rate_rounded,
        ),
        _buildStatItem(
          '100%', // Placeholder for response rate
          'Response',
          Icons.chat_bubble_outline,
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
