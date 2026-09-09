import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:dartz/dartz.dart';

class CollectPaymentUseCase {
  final PaymentRepository _repository;

  CollectPaymentUseCase({required PaymentRepository repository})
    : _repository = repository;

  Future<Either<Failure, String>> call({
    required int amount,
    required String phoneNumber,
    required String externalReference,
    required String medium,
  }) {
    return _repository.collect(
      amount: amount,
      phoneNumber: phoneNumber,
      externalReference: externalReference,
      medium: medium,
    );
  }
}
