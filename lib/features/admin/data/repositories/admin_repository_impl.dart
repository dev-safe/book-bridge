import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/admin/data/datasources/rust_admin_data_source.dart';
import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';
import 'package:book_bridge/features/admin/domain/repositories/admin_repository.dart';
import 'package:dartz/dartz.dart';

class AdminRepositoryImpl implements AdminRepository {
  final RustAdminDataSource _dataSource;

  AdminRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, Unit>> checkAdmin() =>
      _done(() => _dataSource.checkAdmin());

  @override
  Future<Either<Failure, List<AdminDispute>>> disputes() =>
      _guard(() => _dataSource.disputes());

  @override
  Future<Either<Failure, List<UnmatchedPayment>>> unmatchedPayments() =>
      _guard(() => _dataSource.unmatchedPayments());

  @override
  Future<Either<Failure, Unit>> releaseDispute(
    String transactionId,
    String note,
  ) => _done(() => _dataSource.releaseDispute(transactionId, note));

  @override
  Future<Either<Failure, Unit>> refundDispute(
    String transactionId,
    String note, {
    String? phone,
  }) =>
      _done(() => _dataSource.refundDispute(transactionId, note, phone: phone));

  @override
  Future<Either<Failure, Unit>> refundUnmatched(
    String id,
    String note, {
    String? phone,
  }) => _done(() => _dataSource.refundUnmatched(id, note, phone: phone));

  @override
  Future<Either<Failure, Unit>> dismissUnmatched(String id, String note) =>
      _done(() => _dataSource.dismissUnmatched(id, note));

  Future<Either<Failure, Unit>> _done(Future<void> Function() run) =>
      _guard(() async {
        await run();
        return unit;
      });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
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
