import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';
import 'package:book_bridge/features/admin/domain/repositories/admin_repository.dart';
import 'package:book_bridge/features/admin/presentation/screens/admin_screen.dart';
import 'package:book_bridge/features/admin/presentation/viewmodels/admin_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo implements AdminRepository {
  Either<Failure, Unit> access = const Right(unit);
  Either<Failure, Unit> actionResult = const Right(unit);
  List<AdminDispute> disputeList = const [
    AdminDispute(transactionId: 't1', amount: 500),
  ];
  final calls = <String>[];

  @override
  Future<Either<Failure, Unit>> checkAdmin() async => access;

  @override
  Future<Either<Failure, List<AdminDispute>>> disputes() async {
    calls.add('disputes');
    return Right(disputeList);
  }

  @override
  Future<Either<Failure, List<UnmatchedPayment>>> unmatchedPayments() async =>
      const Right([UnmatchedPayment(id: 'u1')]);

  @override
  Future<Either<Failure, Unit>> releaseDispute(String id, String note) async {
    calls.add('release $id $note');
    return actionResult;
  }

  @override
  Future<Either<Failure, Unit>> refundDispute(
    String id,
    String note, {
    String? phone,
  }) async {
    calls.add('refund $id $note $phone');
    return actionResult;
  }

  @override
  Future<Either<Failure, Unit>> refundUnmatched(
    String id,
    String note, {
    String? phone,
  }) async => actionResult;

  @override
  Future<Either<Failure, Unit>> dismissUnmatched(
    String id,
    String note,
  ) async => actionResult;
}

void main() {
  late _FakeRepo repo;
  late AdminViewModel vm;

  setUp(() {
    repo = _FakeRepo();
    vm = AdminViewModel(repo);
  });

  test('open loads both lists for admins', () async {
    await vm.open();

    expect(vm.state, AdminLoadState.loaded);
    expect(vm.disputes.single.transactionId, 't1');
    expect(vm.unmatched.single.id, 'u1');
    expect(vm.error, isNull);
  });

  test('open denies non-admins without loading lists', () async {
    repo.access = const Left(ServerFailure(message: 'Admin access required'));

    await vm.open();

    expect(vm.state, AdminLoadState.denied);
    expect(vm.error, 'Admin access required');
    expect(repo.calls, isEmpty);
  });

  test('a successful action returns null and reloads the lists', () async {
    await vm.open();
    repo.disputeList = const [];

    final error = await vm.refundDispute(
      't1',
      'never sent',
      phone: '677123456',
    );

    expect(error, isNull);
    expect(repo.calls, contains('refund t1 never sent 677123456'));
    expect(vm.disputes, isEmpty);
    expect(vm.busyId, isNull);
  });

  test('a failed action returns the server message', () async {
    await vm.open();
    repo.actionResult = const Left(
      ServerFailure(message: 'A refund is already in progress'),
    );

    final error = await vm.releaseDispute('t1', 'proof');

    expect(error, 'A refund is already in progress');
    expect(vm.busyId, isNull);
  });

  group('dialog validation', () {
    test('note is required and capped at 1000 characters', () {
      expect(validateAdminNote(null), isNotNull);
      expect(validateAdminNote('   '), isNotNull);
      expect(validateAdminNote('x' * 1001), isNotNull);
      expect(validateAdminNote('Seller showed proof'), isNull);
    });

    test('refund phone accepts local and 237-prefixed numbers', () {
      expect(normalizeRefundPhone('677123456'), '677123456');
      expect(normalizeRefundPhone('+237 677 12 34 56'), '677123456');
      expect(normalizeRefundPhone('237677123456'), '677123456');
      expect(normalizeRefundPhone('577123456'), isNull);
      expect(normalizeRefundPhone('67712345'), isNull);
    });
  });
}
