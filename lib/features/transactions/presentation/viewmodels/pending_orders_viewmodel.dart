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
  bool _isRefreshing = false;

  /// Purchases paid into escrow that the buyer still has to confirm.
  int get purchasesToConfirm => _purchasesToConfirm;

  /// Sales held in escrow, waiting for the seller to hand over the book.
  int get salesInEscrow => _salesInEscrow;

  int get totalCount => _purchasesToConfirm + _salesInEscrow;

  bool get hasPending => totalCount > 0;

  Future<void> refresh(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _update(0, 0);
      return;
    }
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final purchasesResult = await useCase.purchases(userId);
      final salesResult = await useCase.sales(userId);
      // Keep the previous counts on failure rather than flashing to zero.
      final purchases = purchasesResult.fold(
        (_) => _purchasesToConfirm,
        _countHeld,
      );
      final sales = salesResult.fold((_) => _salesInEscrow, _countHeld);
      _update(purchases, sales);
    } finally {
      _isRefreshing = false;
    }
  }

  void clear() => _update(0, 0);

  int _countHeld(List<TransactionEntity> items) =>
      items.where((t) => t.status == _heldStatus).length;

  void _update(int purchases, int sales) {
    if (purchases == _purchasesToConfirm && sales == _salesInEscrow) return;
    _purchasesToConfirm = purchases;
    _salesInEscrow = sales;
    notifyListeners();
  }
}
