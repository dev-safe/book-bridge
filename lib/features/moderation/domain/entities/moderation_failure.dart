import 'package:book_bridge/core/error/failures.dart';

enum ModerationFailureKind {
  /// The daily report limit was reached.
  reportLimit,

  /// One of the two users has blocked the other.
  blocked,
  other,
}

class ModerationFailure extends Failure {
  final ModerationFailureKind kind;

  const ModerationFailure({
    required super.message,
    this.kind = ModerationFailureKind.other,
  });

  @override
  List<Object?> get props => [message, kind];
}
