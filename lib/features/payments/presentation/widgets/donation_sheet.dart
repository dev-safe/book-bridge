import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:book_bridge/features/payments/presentation/widgets/payment_bottom_sheet.dart';
import 'package:book_bridge/injection_container.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Preset donation amounts in XAF.
const List<int> donationAmounts = [100, 500, 1000];

/// Shows the in-app donation flow: an amount picker followed by the
/// mobile-money payment sheet. Shared by Home, Profile and About.
Future<void> showDonationSheet(BuildContext context) async {
  final amount = await showModalBottomSheet<int>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const _DonationAmountPicker(),
  );
  if (amount == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final thanks = AppLocalizations.of(context)!.donationThanks;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => ChangeNotifierProvider(
      create: (_) => getIt<PaymentViewModel>(),
      child: PaymentBottomSheet(
        amount: amount,
        title: AppLocalizations.of(sheetContext)!.supportBookBridge,
        purpose: DonationPayment(amount),
        onSuccess: () {
          messenger.showSnackBar(
            SnackBar(content: Text(thanks), backgroundColor: Colors.green),
          );
        },
      ),
    ),
  );
}

class _DonationAmountPicker extends StatelessWidget {
  const _DonationAmountPicker();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.selectDonationAmount,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                for (final amount in donationAmounts)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ElevatedButton(
                        key: ValueKey('donation-amount-$amount'),
                        onPressed: () => Navigator.pop(context, amount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$amount XAF',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
