import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/data/datasources/rust_payments_data_source.dart';
import 'package:book_bridge/features/payments/domain/entities/payment_purpose.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:dartz/dartz.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final RustPaymentsDataSource _dataSource;

  PaymentRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, String>> collect({
    required PaymentPurpose purpose,
    required String phoneNumber,
    String? medium,
  }) {
    return _guard(
      () => _dataSource.initiate(
        purpose: purpose,
        phone: phoneNumber,
        medium: medium,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> getTransactionStatus(String reference) {
    return _guard(() => _dataSource.status(reference));
  }

  Future<Either<Failure, String>> _guard(Future<String> Function() run) async {
    try {
      return Right(await run());
    } on AuthAppException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
