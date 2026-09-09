import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for signing in a user.
class SignInUseCase extends UseCase<User, SignInParams> {
  final AuthRepository repository;

  SignInUseCase({required this.repository});

  @override
  Future<Either<Failure, User>> call(SignInParams params) {
    return repository.signIn(email: params.email, password: params.password);
  }
}

/// Parameters for the SignIn use case.
class SignInParams {
  final String email;
  final String password;

  SignInParams({required this.email, required this.password});
}
