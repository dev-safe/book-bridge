import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';

abstract class PaymentRepository {
  /// Initiates a payment collection.
  /// Returns the transaction reference if successful.
  Future<Either<Failure, String>> collect({
    required int amount,
    required String phoneNumber,
    required String externalReference,
    required String medium,
  });

  /// Checks the status of a transaction.
  Future<Either<Failure, String>> getTransactionStatus(String reference);
}
