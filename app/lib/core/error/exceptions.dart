/// Base exception class for application-specific exceptions.
abstract class AppException implements Exception {
  final String message;

  AppException({required this.message});

  @override
  String toString() => message;
}

/// Exception thrown when authentication fails.
class AuthAppException extends AppException {
  AuthAppException({required super.message});
}

/// Exception thrown when user is not found.
class UserNotFoundException extends AppException {
  UserNotFoundException({required super.message});
}

/// Exception thrown on server/network errors.
class ServerException extends AppException {
  ServerException({required super.message});
}

/// Exception thrown on generic/unexpected errors.
class UnknownException extends AppException {
  UnknownException({required super.message});
}

/// Exception thrown when a resource is not found.
class NotFoundException extends AppException {
  NotFoundException({required super.message});
}
