import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/usecases/get_user_transactions_usecase.dart';
import 'package:flutter/foundation.dart';

/// Tracks escrow orders that need the current user's attention so they can
/// be surfaced outside the Transaction History screen (badges, Home card).
class PendingOrdersViewModel extends ChangeNotifier {
  PendingOrdersViewModel({required this.useCase});

  static const String _heldStatus = 'held';

  final GetUserTransactionsUseCase useCase;

  int _purchasesToConfirm = 0;
  int _salesInEscrow = 0;

  /// The user the current counts belong to.
  String? _userId;

  /// The user a fetch is currently in flight for, if any.
  String? _refreshingFor;

  /// Purchases paid into escrow that the buyer still has to confirm.
  int get purchasesToConfirm => _purchasesToConfirm;

  /// Sales held in escrow, waiting for the seller to hand over the book.
  int get salesInEscrow => _salesInEscrow;

  int get totalCount => _purchasesToConfirm + _salesInEscrow;

  bool get hasPending => totalCount > 0;

  Future<void> refresh(String? userId) async {
    if (userId == null || userId.isEmpty) {
      clear();
      return;
    }
    if (userId != _userId) {
      // Never show another account's counts, even briefly.
      _userId = userId;
      _update(0, 0);
    }
    if (_refreshingFor == userId) return;
    _refreshingFor = userId;
    try {
      final purchasesResult = await useCase.purchases(userId);
      final salesResult = await useCase.sales(userId);
      if (_userId != userId) return;
      // Keep this user's previous counts on failure rather than flashing to 0.
      final purchases = purchasesResult.fold(
        (_) => _purchasesToConfirm,
        _countHeld,
      );
      final sales = salesResult.fold((_) => _salesInEscrow, _countHeld);
      _update(purchases, sales);
    } finally {
      if (_refreshingFor == userId) _refreshingFor = null;
    }
  }

  void clear() {
    _userId = null;
    _update(0, 0);
  }

  int _countHeld(List<TransactionEntity> items) =>
      items.where((t) => t.status == _heldStatus).length;

  void _update(int purchases, int sales) {
    if (purchases == _purchasesToConfirm && sales == _salesInEscrow) return;
    _purchasesToConfirm = purchases;
    _salesInEscrow = sales;
    notifyListeners();
  }
}
