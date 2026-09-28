import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:dartz/dartz.dart';

class CollectPaymentUseCase {
  final PaymentRepository _repository;

  CollectPaymentUseCase({required PaymentRepository repository})
    : _repository = repository;

  Future<Either<Failure, String>> call({
    required PaymentPurpose purpose,
    required String phoneNumber,
    String? medium,
  }) {
    return _repository.collect(
      purpose: purpose,
      phoneNumber: phoneNumber,
      medium: medium,
    );
  }
}
