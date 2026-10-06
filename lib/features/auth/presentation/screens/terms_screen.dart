import 'package:flutter/material.dart';
import 'package:book_bridge/core/constants/feature_flags.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
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
    final primaryColor = AppTheme.headerColor(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    'Welcome to BookBridge, a peer-to-peer textbook marketplace for students in Cameroon. By creating an account or using the app you agree to these terms. Please read them carefully.',
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
                  _buildInterimNotice(context),
                  for (final section in _sections(context))
                    _buildTermCard(
                      context: context,
                      icon: section.icon,
                      title: section.title,
                      color: section.color,
                      content: section.content,
                    ),

                  const SizedBox(height: 24),

                  // Standardized Last Updated Notice (Worth Preserving)
                  Center(
                    child: Text(
                      l10n.lastUpdated('October 2026'),
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

  Widget _buildInterimNotice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.shade900.withValues(alpha: 0.25)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.amber.shade700 : Colors.amber.shade200,
        ),
      ),
      child: Text(
        'Interim terms. This version describes how BookBridge works today. '
        'It is under legal review and will be updated; we will notify you in '
        'the app before any material change takes effect.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: isDark ? Colors.amber.shade100 : Colors.brown.shade800,
        ),
      ),
    );
  }

  static const _paidFeatureTerms =
      '• Power Seller: 500 XAF for 30 days, unlocking unlimited active '
      'listings. It is a one-off payment, not an automatic renewal.\n'
      '• Listing boost: 500 XAF for 7 days of higher visibility.\n';

  List<_TermSection> _sections(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    return [
      _TermSection(
        icon: Icons.groups_outlined,
        title: '1. Who These Terms Cover',
        color: primary,
        content:
            'BookBridge is built for students in Cameroon aged 10 to 22, and '
            'for parents or guardians who buy books on behalf of a student. '
            'These terms apply to everyone who creates an account, lists a '
            'book, buys a book, or otherwise uses the app. If you use '
            'BookBridge on behalf of a minor, you accept these terms for both '
            'yourself and that minor.',
      ),
      _TermSection(
        icon: Icons.storefront_outlined,
        title: '2. How the Marketplace Works',
        color: primary,
        content:
            'Listings are posted by individual users. BookBridge is not the '
            'seller of any book; we provide the platform and process payments '
            'between buyer and seller.\n\n'
            '• Fees: the buyer pays the listed price plus a 6% service fee. '
            'The seller receives 100% of the listed price.\n'
            '• Free sellers may have up to 3 active listings at a time.\n'
            '${kDigitalPaymentsEnabled ? _paidFeatureTerms : ''}\n'
            'Sellers must describe each book honestly (title, edition, '
            'condition) and must only list books they own and can hand over.',
      ),
      _TermSection(
        icon: Icons.account_balance_wallet_outlined,
        title: '3. Payments & Escrow',
        color: Colors.green.shade700,
        content:
            'Payments are made with MTN Mobile Money or Orange Money through '
            'our payment partner, Fapshi. When a buyer pays, the money is held '
            'in escrow; it is not sent to the seller straight away.\n\n'
            '• Buyer confirms receipt: the seller is paid to their registered '
            'Mobile Money number.\n'
            '• Buyer opens a dispute: the money stays held until BookBridge '
            'resolves the dispute.\n'
            '• No response: if the buyer neither confirms nor disputes within '
            '5 days of payment, the money is released to the seller '
            'automatically.\n\n'
            'Sellers must keep a valid Mobile Money number in their profile to '
            'receive payouts.',
      ),
      _TermSection(
        icon: Icons.balance_outlined,
        title: '4. Disputes',
        color: Colors.orange.shade800,
        content:
            'If a book is not handed over, or is materially different from its '
            'listing, the buyer can open a dispute from their transaction '
            'history before the 5-day window ends, giving a short reason. A '
            'BookBridge administrator reviews the case and decides either to '
            'release the payment to the seller or to refund the buyer. '
            'BookBridge\'s decision is final for that transaction. Opening '
            'false disputes is a breach of these terms.',
      ),
      _TermSection(
        icon: Icons.family_restroom_outlined,
        title: '5. Age & Guardians',
        color: primary,
        content:
            'New accounts are open to users aged 10 to 22. Anyone can browse '
            'and list books, but you must verify your identity before you can '
            'buy a book or receive a payout, and buyers cannot pay for books '
            'listed by unverified sellers.\n\n'
            '• 18 and over: your National Identity Card (CNI).\n'
            '• 15 to 17: your school ID. Once verified, you may pay and '
            'receive payouts yourself.\n'
            '• 10 to 14: your school ID plus your parent\'s or guardian\'s CNI '
            'and their Mobile Money number. All payments and payouts for the '
            'account use that number, and the parent or guardian is '
            'responsible for them.\n\n'
            'A BookBridge administrator reviews each submission and may '
            'reject it if the documents are unclear or do not match. Parents '
            'and guardians remain responsible for supervising a minor\'s use '
            'of the app.',
      ),
      _TermSection(
        icon: Icons.lock_outline_rounded,
        title: '6. Data & Privacy',
        color: Colors.teal.shade700,
        content:
            'We collect the information needed to run the marketplace: your '
            'name, email, profile details, school and locality, your listings '
            'and messages, your age declaration, and your Mobile Money payout '
            'number. We use it to operate accounts, process payments and '
            'payouts, prevent fraud, and resolve disputes.\n\n'
            'For identity verification we also collect your date of birth, '
            'photos of your ID documents and, for users aged 10 to 14, a '
            'parent\'s or guardian\'s Mobile Money number. ID photos are '
            'stored privately, seen only by BookBridge administrators, and '
            'deleted once the review is complete; we keep only the result, '
            'the type of ID and your date of birth.\n\n'
            'Your contact details are shared only with the other party in a '
            'transaction. We never sell your data. We process personal data, '
            'including that of minors, in line with Cameroon\'s laws on '
            'personal data protection. See our Privacy Policy for details, and '
            'contact us to access or delete your data.',
      ),
      _TermSection(
        icon: Icons.share_location_outlined,
        title: '7. Safety & Meetups',
        color: secondary,
        content:
            'Handovers are arranged directly between buyer and seller. Suggested '
            'meetup points are suggestions only, not guarantees of safety. '
            'Meet in daylight in busy public places, bring a friend or tell an '
            'adult where you are going, inspect the book before confirming '
            'receipt, and never pay outside the app. BookBridge is not '
            'responsible for what happens during in-person meetings between '
            'users.',
      ),
      _TermSection(
        icon: Icons.block_outlined,
        title: '8. Prohibited Conduct',
        color: Colors.red.shade700,
        content:
            '• Fraud, scams, or fake or misleading listings\n'
            '• Selling the same book to more than one buyer\n'
            '• Moving a deal off the app to avoid fees or escrow\n'
            '• Counterfeit, photocopied, stolen, or non-educational items\n'
            '• Harassment, threats, or abuse of other users\n'
            '• Impersonating another person or giving false age, identity, or '
            'payment details',
      ),
      _TermSection(
        icon: Icons.gpp_maybe_outlined,
        title: '9. Account Suspension & Reporting',
        color: Colors.grey.shade800,
        content:
            'We may suspend or close accounts that break these terms or the '
            'law, and may hold related payments while we investigate. To report '
            'a user, listing, or problem, use Contact Us in the app. If you '
            'believe your account was suspended in error, contact us within 30 '
            'days and we will review the decision.\n\n'
            'BookBridge provides the platform "as is". To the extent permitted '
            'by law, we are not liable for losses arising from dealings between '
            'users outside our payment and escrow process.',
      ),
      _TermSection(
        icon: Icons.support_agent_outlined,
        title: '10. Changes & Contact',
        color: primary,
        content:
            'We may update these terms as the service grows. The date at the '
            'bottom of this page shows the latest version, and we will tell you '
            'in the app before any material change takes effect. Continuing to '
            'use BookBridge after a change means you accept the updated terms. '
            'These terms are governed by the laws of the Republic of Cameroon. '
            'Questions? Reach us through Contact Us in the app.',
      ),
    ];
  }

  Widget _buildTermCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Section accents are tuned for light cards; lift them for dark cards.
    final accent = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 5)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accent,
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
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermSection {
  const _TermSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String content;
  final Color color;
}
