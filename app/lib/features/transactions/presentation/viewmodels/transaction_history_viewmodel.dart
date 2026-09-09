import 'package:flutter/material.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:book_bridge/features/transactions/domain/usecases/get_user_transactions_usecase.dart';

enum TransactionLoadState { idle, loading, loaded, error }

class TransactionHistoryViewModel extends ChangeNotifier {
  final GetUserTransactionsUseCase useCase;
  final TransactionRepository repository;

  TransactionHistoryViewModel({
    required this.useCase,
    required this.repository,
  });

  TransactionLoadState _state = TransactionLoadState.idle;
  List<TransactionEntity> _purchases = [];
  List<TransactionEntity> _sales = [];
  String? _error;
  bool _isActionLoading = false;

  TransactionLoadState get state => _state;
  List<TransactionEntity> get purchases => _purchases;
  List<TransactionEntity> get sales => _sales;
  String? get error => _error;
  bool get isActionLoading => _isActionLoading;

  Future<void> load(String userId) async {
    _state = TransactionLoadState.loading;
    _error = null;
    _isActionLoading = false;
    notifyListeners();

    final purchasesResult = await useCase.purchases(userId);
    final salesResult = await useCase.sales(userId);

    purchasesResult.fold(
      (failure) => _error = failure.message,
      (data) => _purchases = data,
    );

    salesResult.fold(
      (failure) => _error ??= failure.message,
      (data) => _sales = data,
    );

    _state = TransactionLoadState.loaded;
    notifyListeners();
  }

  Future<bool> confirmReceipt(String transactionId, String userId) async {
    _isActionLoading = true;
    _error = null;
    notifyListeners();

    final result = await repository.confirmReceipt(transactionId);

    bool isSuccess = false;
    await result.fold(
      (failure) async {
        _error = failure.message;
        _isActionLoading = false;
        notifyListeners();
      },
      (success) async {
        isSuccess = true;
        await load(userId);
      },
    );

    return isSuccess;
  }

  Future<bool> disputeTransaction(
    String transactionId,
    String reason,
    String userId,
  ) async {
    _isActionLoading = true;
    _error = null;
    notifyListeners();

    final result = await repository.disputeTransaction(transactionId, reason);

    bool isSuccess = false;
    await result.fold(
      (failure) async {
        _error = failure.message;
        _isActionLoading = false;
        notifyListeners();
      },
      (success) async {
        isSuccess = true;
        await load(userId);
      },
    );

    return isSuccess;
  }
}
