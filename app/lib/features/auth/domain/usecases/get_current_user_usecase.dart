import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for getting the current authenticated user.
class GetCurrentUserUseCase extends UseCaseNoParams<User> {
  final AuthRepository repository;

  GetCurrentUserUseCase({required this.repository});

  @override
  Future<Either<Failure, User>> call() {
    return repository.getCurrentUser();
  }
}
