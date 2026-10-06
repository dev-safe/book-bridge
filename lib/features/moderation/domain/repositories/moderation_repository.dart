import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/moderation/domain/entities/blocked_user.dart';
import 'package:book_bridge/features/moderation/domain/entities/report_reason.dart';
import 'package:dartz/dartz.dart';

/// Reporting and blocking, required for user-generated content on Google
/// Play. Reports go to the admin queue; blocks hide the other user's
/// listings and conversations and stop messages in both directions.
abstract class ModerationRepository {
  Future<Either<Failure, List<BlockedUser>>> getBlockedUsers();

  /// Blocking someone already blocked succeeds.
  Future<Either<Failure, Unit>> blockUser(String userId);

  Future<Either<Failure, Unit>> unblockUser(String userId);

  /// Reporting the same listing again while the first report is open
  /// succeeds without filing a duplicate.
  Future<Either<Failure, Unit>> reportListing(
    String listingId,
    ReportReason reason, {
    String? details,
  });

  Future<Either<Failure, Unit>> reportUser(
    String userId,
    ReportReason reason, {
    String? details,
  });
}
