import 'package:flutter/material.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.faqTitle),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryHeader(
            context,
            AppLocalizations.of(context)!.faqGeneralCategory,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqWhatIsBookBridgeQ,
            AppLocalizations.of(context)!.faqWhatIsBookBridgeA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqCreateAccountQ,
            AppLocalizations.of(context)!.faqCreateAccountA,
          ),

          const SizedBox(height: 24),
          _buildCategoryHeader(
            context,
            AppLocalizations.of(context)!.faqBuyingCategory,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqHowToBuyQ,
            AppLocalizations.of(context)!.faqHowToBuyA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqHowToPayQ,
            AppLocalizations.of(context)!.faqHowToPayA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqNearbyBooksQ,
            AppLocalizations.of(context)!.faqNearbyBooksA,
          ),

          const SizedBox(height: 24),
          _buildCategoryHeader(
            context,
            AppLocalizations.of(context)!.faqSellingCategory,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqHowToListQ,
            AppLocalizations.of(context)!.faqHowToListA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqSellingFeesQ,
            AppLocalizations.of(context)!.faqSellingFeesA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqBuyBackEligibleQ,
            AppLocalizations.of(context)!.faqBuyBackEligibleA,
          ),

          const SizedBox(height: 24),
          _buildCategoryHeader(
            context,
            AppLocalizations.of(context)!.faqSafetyCategory,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqTrustworthySellerQ,
            AppLocalizations.of(context)!.faqTrustworthySellerA,
          ),
          _buildFaqItem(
            context,
            AppLocalizations.of(context)!.faqProblemQ,
            AppLocalizations.of(context)!.faqProblemA,
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedAlignment: Alignment.topLeft,
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
