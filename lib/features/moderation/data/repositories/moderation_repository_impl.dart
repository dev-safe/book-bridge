import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/data/datasources/supabase_moderation_data_source.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/domain/entities/moderation_failure.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:book_bridge/features/moderation/domain/repositories/moderation_repository.dart';
import 'package:dartz/dartz.dart';

class ModerationRepositoryImpl implements ModerationRepository {
  final SupabaseModerationDataSource dataSource;

  ModerationRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<BlockedUser>>> getBlockedUsers() =>
      _guard(dataSource.getBlockedUsers);

  @override
  Future<Either<Failure, Unit>> blockUser(String userId) =>
      _done(() => dataSource.blockUser(userId));

  @override
  Future<Either<Failure, Unit>> unblockUser(String userId) =>
      _done(() => dataSource.unblockUser(userId));

  @override
  Future<Either<Failure, Unit>> reportListing(
    String listingId,
    ReportReason reason, {
    String? details,
  }) => _done(
    () => dataSource.report(
      listingId: listingId,
      reason: reason,
      details: details,
    ),
  );

  @override
  Future<Either<Failure, Unit>> reportUser(
    String userId,
    ReportReason reason, {
    String? details,
  }) => _done(
    () => dataSource.report(
      reportedUserId: userId,
      reason: reason,
      details: details,
    ),
  );

  Future<Either<Failure, Unit>> _done(Future<void> Function() run) =>
      _guard(() async {
        await run();
        return unit;
      });

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on ReportLimitException catch (e) {
      return Left(
        ModerationFailure(
          message: e.message,
          kind: ModerationFailureKind.reportLimit,
        ),
      );
    } on AppException catch (e) {
      return Left(ModerationFailure(message: e.message));
    } catch (e) {
      return Left(ModerationFailure(message: e.toString()));
    }
  }
}
