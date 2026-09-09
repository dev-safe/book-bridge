import 'package:flutter/material.dart';

/// A bottom sheet modal that displays the BookBridge Marketplace Agreement.
///
/// Users must scroll through the terms, check the agreement checkbox,
/// and tap "I Agree" before their account is created.
Future<bool> showMarketplaceAgreement(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => const _MarketplaceAgreementSheet(),
  );
  return result ?? false;
}

class _MarketplaceAgreementSheet extends StatefulWidget {
  const _MarketplaceAgreementSheet();

  @override
  State<_MarketplaceAgreementSheet> createState() =>
      _MarketplaceAgreementSheetState();
}

class _MarketplaceAgreementSheetState
    extends State<_MarketplaceAgreementSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gavel_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marketplace Agreement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Please read carefully before joining',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // Scrollable terms content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeBanner(primaryColor),
                      const SizedBox(height: 20),
                      _buildSection(
                        icon: Icons.shopping_bag_outlined,
                        title: '1. How Purchases Work',
                        color: primaryColor,
                        content:
                            'BookBridge connects buyers and sellers of used books. When you tap "Buy Now" on a listing, you initiate a secure payment through Fapshi — a trusted Cameroonian mobile payment provider.\n\n'
                            'Payments can be made via MTN Mobile Money or Orange Money. You will receive a prompt on your phone to confirm the payment using your PIN.',
                      ),
                      _buildSection(
                        icon: Icons.percent_rounded,
                        title: '2. Commission & Seller Payouts',
                        color: const Color(0xFF2E7D32),
                        content:
                            'BookBridge charges a 5% platform commission on every successful sale to sustain the service for students across Cameroon.\n\n'
                            '✅ Seller receives: 95% of the sale price\n'
                            '📊 BookBridge commission: 5% of the sale price\n\n'
                            'Payouts are processed automatically to the seller\'s registered Mobile Money number within minutes of a confirmed payment.',
                        highlight: true,
                      ),
                      _buildSection(
                        icon: Icons.phone_android_rounded,
                        title: '3. Mobile Money Number',
                        color: primaryColor,
                        content:
                            'To receive payouts as a seller, you must provide a valid Cameroon Mobile Money number (MTN or Orange) in your profile. This number is used exclusively for sending your earnings.\n\n'
                            'Make sure your number is active and can receive Mobile Money transfers before listing books for sale.',
                      ),
                      _buildSection(
                        icon: Icons.handshake_outlined,
                        title: '4. Book Exchange & Delivery',
                        color: primaryColor,
                        content:
                            'BookBridge facilitates the payment — the physical handover of the book is arranged directly between buyer and seller via in-app chat.\n\n'
                            'Both parties are expected to agree on a safe, convenient meeting point. We recommend public locations on campus or at nearby bookshops.',
                      ),
                      _buildSection(
                        icon: Icons.verified_user_outlined,
                        title: '5. Buyer & Seller Responsibilities',
                        color: primaryColor,
                        content:
                            '• Sellers must ensure book descriptions and condition are accurate.\n'
                            '• Buyers must complete payment before expecting the book.\n'
                            '• Both parties must communicate respectfully via in-app chat.\n'
                            '• Fraudulent listings or payment disputes should be reported to BookBridge support immediately.',
                      ),
                      _buildSection(
                        icon: Icons.block_outlined,
                        title: '6. Prohibited Activities',
                        color: Colors.red.shade700,
                        content:
                            '❌ Posting counterfeit, stolen, or prohibited materials\n'
                            '❌ Attempting to transact outside the app to avoid fees\n'
                            '❌ Sharing false contact or payment information\n'
                            '❌ Harassment, threats, or abuse of other users\n\n'
                            'Violations may result in immediate account suspension.',
                      ),
                      _buildSection(
                        icon: Icons.privacy_tip_outlined,
                        title: '7. Privacy & Data',
                        color: primaryColor,
                        content:
                            'By creating an account, you agree that BookBridge may collect and store your name, email, locality, and Mobile Money number to provide the marketplace service.\n\n'
                            'Your contact information is shared with transaction counterparties only when a purchase is initiated. We do not sell your data to third parties.',
                      ),
                      _buildSection(
                        icon: Icons.support_agent_outlined,
                        title: '8. Dispute Resolution',
                        color: primaryColor,
                        content:
                            'If a transaction goes wrong (e.g., book not received, payment not settled), contact BookBridge support via the "Contact Us" section in the app.\n\n'
                            'We will review the case and assist in mediation. However, BookBridge is not liable for losses resulting from in-person exchange disputes.',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'These terms apply to all users of BookBridge. By agreeing, you confirm you are at least 13 years old and have the authority to use Mobile Money services in Cameroon.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Agreement checkbox + Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                color: Colors.white,
                child: Column(
                  children: [
                    // Checkbox row
                    GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _agreed
                                  ? primaryColor
                                  : Colors.transparent,
                              border: Border.all(
                                color: _agreed
                                    ? primaryColor
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _agreed
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'I have read and agree to the BookBridge Marketplace Agreement and understand how commissions and payouts work.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buttons row
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // I Agree button
                        Expanded(
                          flex: 2,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _agreed ? 1.0 : 0.4,
                            child: ElevatedButton(
                              onPressed: _agreed
                                  ? () => Navigator.of(context).pop(true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'I Agree',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Bottom safe area padding
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeBanner(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white, size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to BookBridge! 📚',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'A peer-to-peer book marketplace built for students in Cameroon. Please review how our platform works before joining.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF2E7D32).withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
