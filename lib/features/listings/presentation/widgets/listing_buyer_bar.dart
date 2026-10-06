import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Compact sticky action row shown to buyers on the listing details screen:
/// price on the left, a chat shortcut and the primary Buy call-to-action.
///
/// When [isAvailable] is false the chat shortcut is hidden and the Buy button
/// is disabled with a "SOLD" label.
class ListingBuyerBar extends StatelessWidget {
  final int priceFcfa;
  final bool isAvailable;
  final VoidCallback onChat;
  final VoidCallback onBuy;

  const ListingBuyerBar({
    super.key,
    required this.priceFcfa,
    required this.isAvailable,
    required this.onChat,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 4, child: _PriceBlock(priceFcfa: priceFcfa)),
        if (isAvailable) ...[
          _ChatButton(onPressed: onChat),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 5,
          child: _BuyButton(isAvailable: isAvailable, onPressed: onBuy),
        ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  final int priceFcfa;

  const _PriceBlock({required this.priceFcfa});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.priceTitle,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.priceFormat(priceFcfa),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ChatButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 52,
      height: 52,
      child: Tooltip(
        message: l10n.messageSeller,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: primary,
            side: BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            semanticLabel: l10n.messageSeller,
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
