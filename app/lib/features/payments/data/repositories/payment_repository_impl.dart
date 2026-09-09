import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/payments/data/datasources/fapshi_data_source.dart';
import 'package:book_bridge/features/payments/domain/repositories/payment_repository.dart';
import 'package:dartz/dartz.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final FapshiDataSource _dataSource;

  PaymentRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, String>> collect({
    required int amount,
    required String phoneNumber,
    required String externalReference,
    required String medium,
  }) async {
    try {
      final response = await _dataSource.directPay(
        amount: amount,
        phone: phoneNumber,
        externalId: externalReference,
        medium: medium,
      );

      // Fapshi returns transId in the response body
      final transId = response['transId'] as String?;
      if (transId != null) {
        return Right(transId);
      } else {
        return const Left(
          ServerFailure(message: 'No transaction ID returned from Fapshi'),
        );
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getTransactionStatus(String reference) async {
    try {
      final result = await _dataSource.paymentStatus(reference);
      final status = result['status'] as String?;

      if (status != null) {
        return Right(status);
      } else {
        return const Left(
          ServerFailure(message: 'No status returned from Fapshi'),
        );
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
