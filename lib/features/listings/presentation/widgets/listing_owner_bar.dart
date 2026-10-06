import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Sticky action area shown to the owner on the listing details screen:
/// an "Edit Listing" button, with a paid boost above it when [onBoost] is set.
class ListingOwnerBar extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback? onBoost;

  const ListingOwnerBar({super.key, required this.onEdit, this.onBoost});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final boost = onBoost;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (boost != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: boost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bridgeOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.rocket_launch, size: 20),
              label: Text(
                l10n.boostListing,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.boostListingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(
              l10n.editListing,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
