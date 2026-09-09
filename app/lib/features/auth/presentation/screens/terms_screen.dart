import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Comprehensive and beautifully styled Terms & Conditions screen.
///
/// Designed to establish trust and safety for the BookBridge marketplace in Cameroon.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            color: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    size: 24,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.termsAndConditionsTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balancing width of back button
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Trust & Integrity Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Marketplace Trust & Safety',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to BookBridge! A peer-to-peer textbook marketplace built to empower students in Cameroon. Please read these terms carefully to understand our community guidelines, payout structures, and safety standards.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: User Responsibilities
                  _buildTermCard(
                    context: context,
                    icon: Icons.assignment_turned_in_outlined,
                    title: '1. User & Listing Responsibilities',
                    color: primaryColor,
                    content:
                        'Sellers are strictly required to ensure that all book details, including titles, authors, editions, and categories, are accurate. Honest condition grading (New, Like New, Good, Fair, Poor) must be adhered to. Buyers are expected to complete payments in full before claiming a book.',
                  ),

                  // Section 2: Prohibited Items
                  _buildTermCard(
                    context: context,
                    icon: Icons.report_problem_outlined,
                    title: '2. Prohibited Items',
                    color: Colors.red.shade700,
                    content:
                        'To maintain an academic and safe ecosystem, users are prohibited from listing counterfeit/photocopied books, stolen books, or non-educational content. Listing dangerous, explicit, or unrelated materials will result in immediate and permanent account suspension.',
                  ),

                  // Section 3: Payment Policy & Commissions
                  _buildTermCard(
                    context: context,
                    icon: Icons.monetization_on_outlined,
                    title: '3. Payments & Commission Disclosure',
                    color: Colors.green.shade700,
                    content:
                        'Payments are handled securely via our Fapshi payment integration using MTN Mobile Money or Orange Money. To keep BookBridge running and free of intrusive ads, a small success fee/commission of 5% to 15% is deducted from the seller\'s payout at transaction clearance. Refunds are available if a listing is verified as fraudulent before handover.',
                  ),

                  // Section 4: Safety & Meetups
                  _buildTermCard(
                    context: context,
                    icon: Icons.share_location_outlined,
                    title: '4. Safety & Campus Meetups',
                    color: Theme.of(context).colorScheme.secondary,
                    content:
                        'Physical handovers are arranged directly between the buyer and the seller. For your safety, always meet in broad daylight at well-populated campus exchange points (e.g., ICT University, Univ of Yaoundé I, or Univ of Buea main squares). Always inspect the book condition before parting ways. Never share personal home addresses or send upfront payments via unverified external channels.',
                  ),

                  // Section 5: Data Privacy
                  _buildTermCard(
                    context: context,
                    icon: Icons.lock_outline_rounded,
                    title: '5. Data Privacy Statement',
                    color: Colors.teal.shade700,
                    content:
                        'Your privacy is paramount. BookBridge securely processes your profile information, phone numbers, and payment details via Supabase strictly for transaction processing and verification. We never sell student data to third parties. Contact info is only shared between active transaction counterparties to facilitate the exchange.',
                  ),

                  // Section 6: Limitation of Liability
                  _buildTermCard(
                    context: context,
                    icon: Icons.shield_outlined,
                    title: '6. Limitation of Liability',
                    color: Colors.grey.shade700,
                    content:
                        'BookBridge provides the platform to connect student buyers and sellers. While we do our best to mediate disputes, BookBridge is not legally liable for losses, fraud, or physical conflicts that occur during in-person meetups outside of our electronic transaction framework.',
                  ),

                  const SizedBox(height: 24),

                  // Standardized Last Updated Notice (Worth Preserving)
                  Center(
                    child: Text(
                      l10n.lastUpdated('May 2026'),
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
