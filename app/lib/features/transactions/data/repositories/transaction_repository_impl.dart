import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/transactions/data/datasources/supabase_transactions_data_source.dart';
import 'package:book_bridge/features/transactions/domain/entities/transaction_entity.dart';
import 'package:book_bridge/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:dartz/dartz.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final SupabaseTransactionsDataSource dataSource;
  TransactionRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<TransactionEntity>>> getPurchases(
    String userId,
  ) async {
    try {
      final result = await dataSource.getPurchases(userId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getSales(
    String userId,
  ) async {
    try {
      final result = await dataSource.getSales(userId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransactionByExternalRef(
    String externalRef,
  ) async {
    try {
      final result = await dataSource.getTransactionByExternalRef(externalRef);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> confirmReceipt(String transactionId) async {
    try {
      await dataSource.confirmReceipt(transactionId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> disputeTransaction(
    String transactionId,
    String reason,
  ) async {
    try {
      await dataSource.disputeTransaction(transactionId, reason);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
