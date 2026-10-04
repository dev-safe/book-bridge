import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';

abstract class PaymentRepository {
  /// Sends a Mobile Money payment prompt for [purpose] to [phoneNumber].
  /// Returns the payment's transaction reference if successful.
  Future<Either<Failure, String>> collect({
    required PaymentPurpose purpose,
    required String phoneNumber,
    String? medium,
  });

  /// Checks the status of a transaction.
  Future<Either<Failure, String>> getTransactionStatus(String reference);
}
