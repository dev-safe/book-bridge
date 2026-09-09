import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';

/// Abstract repository for authentication operations.
///
/// This interface defines the contract for all authentication-related
/// data operations. The actual implementation is in the data layer.
abstract class AuthRepository {
  /// Signs up a new user with email and password.
  ///
  /// Returns either a [Failure] or the newly created [User].
  Future<Either<Failure, User>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String locality,
    required String whatsappNumber,
  });

  /// Signs in a user with email and password.
  ///
  /// Returns either a [Failure] or the authenticated [User].
  Future<Either<Failure, User>> signIn({
    required String email,
    required String password,
  });

  /// Signs out the currently authenticated user.
  ///
  /// Returns either a [Failure] or void (null on success).
  Future<Either<Failure, void>> signOut();

  /// Retrieves the currently authenticated user.
  ///
  /// Returns either a [Failure] or the current [User].
  /// Returns [NotAuthenticatedFailure] if no user is authenticated.
  Future<Either<Failure, User>> getCurrentUser();
  Stream<User?> get authStateChanges;
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
  Future<Either<Failure, User>> signInWithGoogle();
  Future<Either<Failure, User>> updateUser(User user);
  Future<Either<Failure, void>> updateFcmToken(String userId, String token);
  Future<Either<Failure, User>> getUserById(String userId);
}
