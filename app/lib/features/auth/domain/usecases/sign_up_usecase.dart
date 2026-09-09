import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for signing up a new user.
class SignUpUseCase extends UseCase<User, SignUpParams> {
  final AuthRepository repository;

  SignUpUseCase({required this.repository});

  @override
  Future<Either<Failure, User>> call(SignUpParams params) {
    return repository.signUp(
      email: params.email,
      password: params.password,
      fullName: params.fullName,
      locality: params.locality,
      whatsappNumber: params.whatsappNumber,
    );
  }
}

/// Parameters for the SignUp use case.
class SignUpParams {
  final String email;
  final String password;
  final String fullName;
  final String locality;
  final String whatsappNumber;

  SignUpParams({
    required this.email,
    required this.password,
    required this.fullName,
    required this.locality,
    required this.whatsappNumber,
  });
}
