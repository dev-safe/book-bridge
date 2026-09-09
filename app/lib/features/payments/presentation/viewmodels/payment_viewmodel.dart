import 'package:book_bridge/features/payments/domain/usecases/collect_payment_usecase.dart';
import 'package:book_bridge/features/payments/domain/usecases/get_payment_status_usecase.dart';
import 'package:flutter/material.dart';

enum PaymentState { initial, processing, pendingUser, success, failure }

class PaymentViewModel extends ChangeNotifier {
  final CollectPaymentUseCase _collectPaymentUseCase;
  final GetPaymentStatusUseCase _getPaymentStatusUseCase;

  PaymentViewModel({
    required CollectPaymentUseCase collectPaymentUseCase,
    required GetPaymentStatusUseCase getPaymentStatusUseCase,
  }) : _collectPaymentUseCase = collectPaymentUseCase,
       _getPaymentStatusUseCase = getPaymentStatusUseCase;

  PaymentState _state = PaymentState.initial;
  String? _errorMessage;
  String? _transactionReference;

  PaymentState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get transactionReference => _transactionReference;

  Future<void> collectPayment({
    required int amount,
    required String phoneNumber,
    required String externalReference,
    required String medium,
  }) async {
    _state = PaymentState.processing;
    _errorMessage = null;
    notifyListeners();

    final result = await _collectPaymentUseCase(
      amount: amount,
      phoneNumber: phoneNumber,
      externalReference: externalReference,
      medium: medium,
    );

    result.fold(
      (failure) {
        _state = PaymentState.failure;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (reference) {
        _state = PaymentState.pendingUser;
        _transactionReference = reference;
        notifyListeners();
        // We don't automatically poll here, the webhook handles activation.
        // But for UI feedback, we can provide a manual status check.
      },
    );
  }

  Future<void> checkStatus() async {
    if (_transactionReference == null) return;

    final result = await _getPaymentStatusUseCase(_transactionReference!);

    result.fold(
      (failure) {
        // Don't change state to failure if it's just a check error
        debugPrint('Status check error: ${failure.message}');
      },
      (status) {
        if (status == 'SUCCESSFUL') {
          _state = PaymentState.success;
        } else if (status == 'FAILED') {
          _state = PaymentState.failure;
          _errorMessage = 'Payment failed or was cancelled.';
        }
        notifyListeners();
      },
    );
  }

  void reset() {
    _state = PaymentState.initial;
    _errorMessage = null;
    _transactionReference = null;
    notifyListeners();
  }
}
