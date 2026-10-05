import 'package:book_bridge/features/listings/presentation/widgets/meetup_info_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/features/transactions/presentation/viewmodels/transaction_history_viewmodel.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/core/theme/app_theme.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:book_bridge/features/reviews/presentation/widgets/review_dialog.dart';
import 'package:book_bridge/features/reviews/presentation/viewmodels/review_viewmodel.dart';
import 'package:book_bridge/injection_container.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.transactionHistory),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.purchases),
              Tab(text: l10n.sales),
            ],
          ),
        ),
        body: Consumer<TransactionHistoryViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.state == TransactionLoadState.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.state == TransactionLoadState.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(viewModel.error ?? l10n.somethingWentWrong),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // In a real app we'd need the userId here,
                        // but the ViewModel usually has it or we can get it from Auth
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              children: [
                _TransactionList(
                  transactions: viewModel.purchases,
                  isPurchase: true,
                ),
                _TransactionList(
                  transactions: viewModel.sales,
                  isPurchase: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<TransactionEntity> transactions;
  final bool isPurchase;

  const _TransactionList({
    required this.transactions,
    required this.isPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTransactionsYet,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.transactionsEmptySubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _TransactionItem(
          transaction: transaction,
          isPurchase: isPurchase,
        );
      },
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionEntity transaction;
  final bool isPurchase;

  const _TransactionItem({required this.transaction, required this.isPurchase});

  static const _escrowButtonPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 10,
  );

  void _showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  void _showConfirmReceiptDialog(
    BuildContext context,
    TransactionHistoryViewModel viewModel,
  ) {
    // Captured up front: the dialog's own context is gone once it closes,
    // so it can't be used to dismiss the loading overlay afterwards.
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text("Confirm Receipt"),
          ],
        ),
        content: const Text(
          "By confirming, you agree that you have received the book in the described condition. "
          "The funds will be released to the seller immediately. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          FilledButton.icon(
            onPressed: () async {
              navigator.pop();
              _showLoadingOverlay(context);
              final success = await viewModel.confirmReceipt(
                transaction.id,
                transaction.buyerId,
              );
              navigator.pop(); // Close loading overlay
              messenger.showSnackBar(
                success
                    ? const SnackBar(
                        content: Text(
                          "Receipt confirmed. Payout released to seller!",
                        ),
                        backgroundColor: Colors.green,
                      )
                    : SnackBar(
                        content: Text(
                          viewModel.error ?? "Failed to confirm receipt",
                        ),
                        backgroundColor: Colors.red,
                      ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text("Confirm"),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(
    BuildContext context,
    TransactionHistoryViewModel viewModel,
  ) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Report a Problem"),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Please describe the issue with this transaction (e.g. seller did not show up, book in poor condition, incorrect book).",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Enter reason for dispute...",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please provide a reason";
                  }
                  if (value.trim().length < 10) {
                    return "Please provide more details (min 10 characters)";
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                navigator.pop();
                _showLoadingOverlay(context);
                final success = await viewModel.disputeTransaction(
                  transaction.id,
                  reasonController.text.trim(),
                  transaction.buyerId,
                );
                navigator.pop(); // Close loading overlay
                messenger.showSnackBar(
                  success
                      ? const SnackBar(
                          content: Text(
                            "Dispute submitted. Admin will review within 48h.",
                          ),
                          backgroundColor: Colors.orange,
                        )
                      : SnackBar(
                          content: Text(
                            viewModel.error ?? "Failed to submit dispute",
                          ),
                          backgroundColor: Colors.red,
                        ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Submit Dispute"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book Image
                Container(
                  width: 60,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: transaction.listingImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            transaction.listingImageUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.book, color: theme.disabledColor),
                ),
                const SizedBox(width: 12),
                // Transaction Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.listingTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.amount}: ${transaction.amountFcfa} FCFA',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${l10n.date}: ${DateFormat.yMMMd().format(transaction.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _StatusBadge(status: transaction.status),
                    ],
                  ),
                ),
                if (isPurchase && transaction.status == 'successful')
                  IconButton(
                    icon: const Icon(Icons.rate_review_outlined),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ChangeNotifierProvider(
                          create: (_) => getIt<ReviewViewModel>(),
                          child: ReviewDialog(
                            reviewerId: transaction.buyerId,
                            revieweeId: transaction.sellerId,
                            listingId: transaction.listingId,
                            transactionId: transaction.id,
                            listingTitle: transaction.listingTitle,
                          ),
                        ),
                      );
                    },
                    tooltip: l10n.leaveReview,
                  ),
              ],
            ),
            if (isPurchase && transaction.status == 'held') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if ((transaction.meetupSpot?.trim().isNotEmpty ?? false) ||
                  (transaction.meetupLatitude != null &&
                      transaction.meetupLongitude != null)) ...[
                MeetupInfoCard(
                  spot: transaction.meetupSpot,
                  latitude: transaction.meetupLatitude,
                  longitude: transaction.meetupLongitude,
                ),
                const SizedBox(height: 12),
              ],
              // Equal-width buttons so long labels (e.g. French) never push
              // past the card edge on narrow phones.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDisputeDialog(
                        context,
                        context.read<TransactionHistoryViewModel>(),
                      ),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: Text(
                        l10n.escrowReportProblem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        padding: _escrowButtonPadding,
                        visualDensity: VisualDensity.compact,
                        textStyle: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showConfirmReceiptDialog(
                        context,
                        context.read<TransactionHistoryViewModel>(),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(
                        l10n.escrowConfirmReceipt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.growthGreen,
                        foregroundColor: Colors.white,
                        padding: _escrowButtonPadding,
                        visualDensity: VisualDensity.compact,
                        textStyle: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isPurchase && transaction.status == 'disputed') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    "Dispute Under Review",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'successful':
      case 'completed':
        color = AppTheme.growthGreen;
        label = l10n.statusSuccessful;
        break;
      case 'pending':
        color = AppTheme.bridgeOrange;
        label = l10n.statusPending;
        break;
      case 'failed':
        color = theme.colorScheme.error;
        label = l10n.statusFailed;
        break;
      case 'held':
        color = Colors.amber;
        label = "Held in Escrow";
        break;
      case 'disputed':
        color = theme.colorScheme.error;
        label = "Disputed";
        break;
      default:
        color = theme.disabledColor;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
