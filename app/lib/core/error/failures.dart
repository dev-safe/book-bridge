import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
/// This is used with `Either<Failure, Success>` pattern (from dartz).
abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Failure for authentication-related errors.
class AuthFailure extends Failure {
  const AuthFailure({required super.message});
}

/// Failure for server/network-related errors.
class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

/// Failure for generic/unexpected errors.
class UnknownFailure extends Failure {
  const UnknownFailure({required super.message});
}

/// Failure when user is not authenticated.
class NotAuthenticatedFailure extends Failure {
  const NotAuthenticatedFailure({required super.message});
}

/// Failure when a resource is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message});
}

/// Failure when the device is offline but valid cached data was served.
///
/// Returned by [ListingRepositoryImpl] when network access fails yet the
/// local SQLite cache still contains valid (within TTL) listings.
/// This is a soft failure — the caller received data and should show
/// the [OfflineBanner] rather than a full error state.
class OfflineCacheFailure extends Failure {
  const OfflineCacheFailure({required super.message});
}
