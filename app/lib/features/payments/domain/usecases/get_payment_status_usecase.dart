import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:dartz/dartz.dart';

class GetPaymentStatusUseCase {
  final PaymentRepository _repository;

  GetPaymentStatusUseCase({required PaymentRepository repository})
    : _repository = repository;

  Future<Either<Failure, String>> call(String reference) {
    return _repository.getTransactionStatus(reference);
  }
}
