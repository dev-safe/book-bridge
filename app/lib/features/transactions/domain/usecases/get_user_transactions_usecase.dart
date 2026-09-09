import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/repositories/transaction_repository.dart';

class GetUserTransactionsUseCase {
  final TransactionRepository repository;
  GetUserTransactionsUseCase(this.repository);

  Future<Either<Failure, List<TransactionEntity>>> purchases(String userId) =>
      repository.getPurchases(userId);

  Future<Either<Failure, List<TransactionEntity>>> sales(String userId) =>
      repository.getSales(userId);
}
