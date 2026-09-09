import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for signing in a user with Google.
class SignInWithGoogleUseCase extends UseCaseNoParams<User> {
  final AuthRepository repository;

  SignInWithGoogleUseCase({required this.repository});

  @override
  Future<Either<Failure, User>> call() {
    return repository.signInWithGoogle();
  }
}
