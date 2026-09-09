import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for signing out the current user.
class SignOutUseCase extends UseCaseNoParams<void> {
  final AuthRepository repository;

  SignOutUseCase({required this.repository});

  @override
  Future<Either<Failure, void>> call() {
    return repository.signOut();
  }
}
