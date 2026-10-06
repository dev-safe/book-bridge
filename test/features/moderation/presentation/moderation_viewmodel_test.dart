import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/domain/blocked_users_cache.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/domain/entities/moderation_failure.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:book_bridge/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:book_bridge/features/moderation/presentation/viewmodels/moderation_viewmodel.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ModerationRepository {}

const _bob = BlockedUser(id: 'u2', name: 'Bob');
const _carol = BlockedUser(id: 'u3', name: 'Carol');
const _failure = ModerationFailure(message: 'offline');

void main() {
  late _MockRepository repository;
  late BlockedUsersCache cache;
  late ModerationViewModel vm;

  setUpAll(() => registerFallbackValue(ReportReason.spam));

  setUp(() {
    repository = _MockRepository();
    cache = BlockedUsersCache();
    vm = ModerationViewModel(repository: repository, cache: cache);
  });

  void stubBlocked(List<BlockedUser> users) => when(
    () => repository.getBlockedUsers(),
  ).thenAnswer((_) async => Right(users));

  group('load', () {
    test('fills the list and the shared cache', () async {
      stubBlocked([_bob]);

      final changed = await vm.load('me');

      expect(changed, isTrue);
      expect(vm.blockedUsers, [_bob]);
      expect(cache.ids, {'u2'});
      expect(vm.isBlocked('u2'), isTrue);
      expect(vm.isLoading, isFalse);
    });

    test('reports no change when the blocks are the same', () async {
      stubBlocked([_bob]);
      await vm.load('me');

      expect(await vm.load('me'), isFalse);
    });

    test('keeps the previous blocks when loading fails', () async {
      stubBlocked([_bob]);
      await vm.load('me');
      when(
        () => repository.getBlockedUsers(),
      ).thenAnswer((_) async => const Left(_failure));

      final changed = await vm.load('me');

      expect(changed, isFalse);
      expect(vm.loadFailure, _failure);
      expect(cache.ids, {'u2'});
    });

    test("switching accounts drops the previous account's blocks", () async {
      stubBlocked([_bob]);
      await vm.load('me');
      when(() => repository.getBlockedUsers()).thenAnswer((_) async {
        // The old blocks are gone before the new ones arrive.
        expect(cache.isEmpty, isTrue);
        return const Right([_carol]);
      });

      await vm.load('someone-else');

      expect(cache.ids, {'u3'});
    });

    test('signed out clears without calling the server', () async {
      stubBlocked([_bob]);
      await vm.load('me');

      expect(await vm.load(null), isTrue);
      expect(cache.isEmpty, isTrue);
      verify(() => repository.getBlockedUsers()).called(1);
    });

    test('reset clears without notifying', () async {
      stubBlocked([_bob]);
      await vm.load('me');
      var notified = false;
      vm.addListener(() => notified = true);

      vm.reset();

      expect(cache.isEmpty, isTrue);
      expect(vm.blockedUsers, isEmpty);
      expect(notified, isFalse);
    });
  });

  group('block and unblock', () {
    test('block adds the user once', () async {
      when(
        () => repository.blockUser('u2'),
      ).thenAnswer((_) async => const Right(unit));

      expect(await vm.block(_bob), isNull);
      expect(await vm.block(_bob), isNull);

      expect(vm.blockedUsers, [_bob]);
      expect(cache.ids, {'u2'});
    });

    test('block failure leaves the list alone', () async {
      when(
        () => repository.blockUser('u2'),
      ).thenAnswer((_) async => const Left(_failure));

      expect(await vm.block(_bob), _failure);
      expect(cache.isEmpty, isTrue);
    });

    test('unblock removes the user', () async {
      stubBlocked([_bob, _carol]);
      await vm.load('me');
      when(
        () => repository.unblockUser('u2'),
      ).thenAnswer((_) async => const Right(unit));

      expect(await vm.unblock('u2'), isNull);

      expect(vm.blockedUsers, [_carol]);
      expect(cache.ids, {'u3'});
    });
  });

  group('report', () {
    test('reportListing passes the reason and details', () async {
      when(
        () => repository.reportListing(
          any(),
          any(),
          details: any(named: 'details'),
        ),
      ).thenAnswer((_) async => const Right(unit));

      final failure = await vm.reportListing(
        'l1',
        ReportReason.scam,
        details: 'fake',
      );

      expect(failure, isNull);
      verify(
        () =>
            repository.reportListing('l1', ReportReason.scam, details: 'fake'),
      ).called(1);
    });

    test('reportUser returns the failure', () async {
      const limit = ModerationFailure(
        message: 'limit',
        kind: ModerationFailureKind.reportLimit,
      );
      when(
        () =>
            repository.reportUser(any(), any(), details: any(named: 'details')),
      ).thenAnswer((_) async => const Left<Failure, Unit>(limit));

      expect(await vm.reportUser('u2', ReportReason.harassment), limit);
    });
  });
}
