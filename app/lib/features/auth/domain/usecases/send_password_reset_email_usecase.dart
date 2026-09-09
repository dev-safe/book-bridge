import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for sending a password reset email.
class SendPasswordResetEmailUseCase extends UseCase<void, String> {
  final AuthRepository repository;

  SendPasswordResetEmailUseCase({required this.repository});

  @override
  Future<Either<Failure, void>> call(String email) {
    return repository.sendPasswordResetEmail(email);
  }
}
