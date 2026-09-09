import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:dartz/dartz.dart';

class GetTransactionByExternalRefUseCase {
  final TransactionRepository repository;

  GetTransactionByExternalRefUseCase(this.repository);

  Future<Either<Failure, TransactionEntity>> call(String externalRef) async {
    return await repository.getTransactionByExternalRef(externalRef);
  }
}
