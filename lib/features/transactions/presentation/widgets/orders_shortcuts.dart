import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/pending_orders_viewmodel.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Opens the orders (transaction history) screen and refreshes the pending
/// counts when the user comes back, since they may have confirmed an order.
Future<void> openMyOrders(BuildContext context) async {
  final pending = context.read<PendingOrdersViewModel>();
  final userId = context.read<AuthViewModel>().currentUser?.id;
  await context.push('/transactions');
  await pending.refresh(userId);
}

/// Header shortcut to "My orders" with a badge for escrow orders that need
/// the user to act.
class OrdersIcon extends StatelessWidget {
  final Color? color;

  const OrdersIcon({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<PendingOrdersViewModel>().totalCount;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.myOrders,
        icon: Badge(
          isLabelVisible: count > 0,
          backgroundColor: AppTheme.bridgeOrange,
          label: Text(count.toString()),
          child: Icon(Icons.receipt_long_outlined, color: color, size: 20),
        ),
        onPressed: () => openMyOrders(context),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }
}

/// Home card shown only while escrow orders are waiting on the user.
class PendingOrdersCard extends StatelessWidget {
  const PendingOrdersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<PendingOrdersViewModel>();
    if (!pending.hasPending) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    const accent = AppTheme.bridgeOrange;
    final lines = [
      if (pending.purchasesToConfirm > 0)
        l10n.ordersToConfirm(pending.purchasesToConfirm),
      if (pending.salesInEscrow > 0)
        l10n.ordersToHandOver(pending.salesInEscrow),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: accent.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openMyOrders(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.receipt_long_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ordersNeedAction,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in lines)
                        Text(
                          line,
                          style: TextStyle(fontSize: 13, color: onSurface),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
