import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/admin/domain/entities/admin_cases.dart';
import 'package:dartz/dartz.dart';

/// Disputes and unmatched payments that need an admin's decision. Every
/// decision takes a note, which the server keeps in its audit trail.
abstract class AdminRepository {
  Future<Either<Failure, Unit>> checkAdmin();
  Future<Either<Failure, List<AdminDispute>>> disputes();
  Future<Either<Failure, List<UnmatchedPayment>>> unmatchedPayments();

  /// Pays the seller as if the buyer had confirmed receipt.
  Future<Either<Failure, Unit>> releaseDispute(
    String transactionId,
    String note,
  );

  /// Refunds the buyer in full, to [phone] or else the number that paid.
  Future<Either<Failure, Unit>> refundDispute(
    String transactionId,
    String note, {
    String? phone,
  });

  Future<Either<Failure, Unit>> refundUnmatched(
    String id,
    String note, {
    String? phone,
  });

  /// Marks an unmatched payment handled without paying anything.
  Future<Either<Failure, Unit>> dismissUnmatched(String id, String note);

  Future<Either<Failure, List<IdVerificationSubmission>>> idVerifications();

  /// Marks the user verified and deletes their ID photos.
  Future<Either<Failure, Unit>> approveId(String userId, String note);

  /// Marks the user rejected, shows them [note] and deletes their ID photos.
  Future<Either<Failure, Unit>> rejectId(String userId, String note);

  /// A short-lived URL for one ID photo.
  Future<Either<Failure, String>> idPhotoUrl(String path);
}
