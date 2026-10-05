import 'package:book_bridge/features/payments/domain/entities/buyer_fee.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:book_bridge/features/payments/presentation/viewmodels/payment_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:book_bridge/l10n/app_localizations.dart';
import 'package:book_bridge/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:book_bridge/features/reviews/presentation/viewmodels/review_viewmodel.dart';
import 'package:book_bridge/features/reviews/presentation/widgets/review_dialog.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/listings/presentation/widgets/meetup_info_card.dart';

class PaymentBottomSheet extends StatefulWidget {
  /// Shown to the user (the book price for purchases; the 6% buyer fee is
  /// added on top). What is actually charged is decided by the server from
  /// [purpose].
  final int amount;
  final String title;
  final PaymentPurpose purpose;
  final VoidCallback onSuccess;

  /// Seller's meetup spot for purchases; shown so the buyer knows where to
  /// collect the book.
  final String? meetupSpot;
  final double? meetupLatitude;
  final double? meetupLongitude;

  const PaymentBottomSheet({
    super.key,
    required this.amount,
    required this.title,
    required this.purpose,
    required this.onSuccess,
    this.meetupSpot,
    this.meetupLatitude,
    this.meetupLongitude,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Widget _meetupCard() => MeetupInfoCard(
    spot: widget.meetupSpot,
    latitude: widget.meetupLatitude,
    longitude: widget.meetupLongitude,
  );

  bool get _hasMeetup =>
      widget.purpose is PurchasePayment &&
      ((widget.meetupSpot?.trim().isNotEmpty ?? false) ||
          (widget.meetupLatitude != null && widget.meetupLongitude != null));

  int get _buyerFee =>
      widget.purpose is PurchasePayment ? buyerFeeFor(widget.amount) : 0;

  @override
  void initState() {
    super.initState();
    if (widget.purpose is PurchasePayment) {
      // The cached status may predate an admin approval.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthViewModel>();
        if (mounted && !auth.isIdVerified) auth.refreshUser();
      });
    }
  }

  void _openIdVerification() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/verify-id');
  }

  Widget _idVerificationRequired(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.badge_outlined, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Text(
          l10n.idVerifyRequiredToBuy,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _openIdVerification,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(l10n.idVerifyNow),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _getMedium(String phone) {
    // Cameroon Mobile Money Prefixes:
    // MTN: 67, 68, 650, 651, 652, 653, 654
    // Orange: 69, 655, 656, 657, 658, 659
    if (phone.startsWith('67') || phone.startsWith('68')) return 'mobile money';
    if (phone.startsWith('69')) return 'orange money';
    if (phone.startsWith('65')) {
      if (phone.length >= 3) {
        final thirdDigit = int.tryParse(phone[2]) ?? 0;
        if (thirdDigit <= 4) return 'mobile money';
        return 'orange money';
      }
    }
    return 'mobile money'; // Default to mobile money
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentViewModel>(
      builder: (context, viewModel, child) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_buyerFee > 0) ...[
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.bookPriceLabel(widget.amount),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.serviceFeeLabel(buyerFeePercent, _buyerFee),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.totalLabel(widget.amount + _buyerFee),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_hasMeetup &&
                      (viewModel.state == PaymentState.initial ||
                          viewModel.state == PaymentState.success)) ...[
                    _meetupCard(),
                    const SizedBox(height: 24),
                  ],
                  if (viewModel.state == PaymentState.initial &&
                      widget.purpose is PurchasePayment &&
                      !context.watch<AuthViewModel>().isIdVerified) ...[
                    _idVerificationRequired(context),
                  ] else if (viewModel.state == PaymentState.initial) ...[
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.phoneNumberLabel,
                          hintText: AppLocalizations.of(
                            context,
                          )!.phoneNumberHint,
                          prefixText: '+237 ',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.fieldRequired;
                          }
                          if (value.length < 9) {
                            return AppLocalizations.of(context)!.invalidNumber;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          viewModel.collectPayment(
                            purpose: widget.purpose,
                            phoneNumber: _phoneController.text,
                            medium: _getMedium(_phoneController.text),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(AppLocalizations.of(context)!.payNow),
                    ),
                  ] else if (viewModel.state == PaymentState.processing) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.initiatingTransaction,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (viewModel.state == PaymentState.pendingUser) ...[
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.confirmPaymentPrompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => viewModel.checkStatus(),
                      child: Text(AppLocalizations.of(context)!.iHavePaid),
                    ),
                  ] else if (viewModel.state == PaymentState.success) ...[
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.paymentSuccessful,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (widget.purpose is PurchasePayment &&
                        viewModel.transactionReference != null) ...[
                      _ReviewPrompt(
                        paymentReference: viewModel.transactionReference!,
                        onCompleted: () {
                          widget.onSuccess();
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        widget.onSuccess();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                      ),
                      child: Text(AppLocalizations.of(context)!.continueButton),
                    ),
                  ] else if (viewModel.state == PaymentState.failure) ...[
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage ??
                          AppLocalizations.of(context)!.unknownError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 24),
                    if (viewModel.errorMessage?.contains(
                          'Verify your identity',
                        ) ??
                        false) ...[
                      ElevatedButton(
                        onPressed: _openIdVerification,
                        child: Text(AppLocalizations.of(context)!.idVerifyNow),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      onPressed: () => viewModel.reset(),
                      child: Text(AppLocalizations.of(context)!.tryAgain),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewPrompt extends StatefulWidget {
  final String paymentReference;
  final VoidCallback onCompleted;

  const _ReviewPrompt({
    required this.paymentReference,
    required this.onCompleted,
  });

  @override
  State<_ReviewPrompt> createState() => _ReviewPromptState();
}

class _ReviewPromptState extends State<_ReviewPrompt> {
  TransactionEntity? _transaction;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransaction();
  }

  Future<void> _fetchTransaction() async {
    final reviewViewModel = context.read<ReviewViewModel>();
    // Wait a bit for Supabase to index the transaction
    final result = await reviewViewModel.getTransactionByExternalRef(
      widget.paymentReference,
    );

    if (mounted) {
      setState(() {
        _transaction = result.fold((_) => null, (t) => t);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_transaction == null) {
      return Text(
        AppLocalizations.of(context)!.reviewLaterHint,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      );
    }

    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReviewDialog(
            transactionId: _transaction!.id,
            listingId: _transaction!.listingId,
            revieweeId: _transaction!.sellerId,
            reviewerId: context.read<AuthViewModel>().currentUser!.id,
            listingTitle: _transaction!.listingTitle,
          ),
        ).then((_) {
          widget.onCompleted();
        });
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(AppLocalizations.of(context)!.leaveAReview),
    );
  }
}
