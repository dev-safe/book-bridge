import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Compact sticky action row shown to buyers on the listing details screen:
/// a "Message Seller" button next to the primary Buy call-to-action.
///
/// When [isAvailable] is false the message button is hidden and the Buy
/// button is disabled with a "SOLD" label.
class ListingBuyerBar extends StatelessWidget {
  final bool isAvailable;
  final VoidCallback onChat;
  final VoidCallback onBuy;

  const ListingBuyerBar({
    super.key,
    required this.isAvailable,
    required this.onChat,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isAvailable) ...[
          Expanded(child: _MessageButton(onPressed: onChat)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _BuyButton(isAvailable: isAvailable, onPressed: onBuy),
        ),
      ],
    );
  }
}

class _MessageButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MessageButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppLocalizations.of(context)!.messageSeller,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final bool isAvailable;
  final VoidCallback onPressed;

  const _BuyButton({required this.isAvailable, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isAvailable ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.bridgeOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          isAvailable
              ? Icons.shopping_bag_outlined
              : Icons.check_circle_outline,
          size: 20,
        ),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isAvailable ? l10n.buyNow : l10n.sold.toUpperCase(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
