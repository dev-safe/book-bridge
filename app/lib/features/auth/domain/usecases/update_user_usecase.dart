import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/auth/domain/entities/user.dart';
import 'package:book_bridge/features/auth/domain/repositories/auth_repository.dart';

/// Use case for updating a user's profile.
class UpdateUserUseCase extends UseCase<User, User> {
  final AuthRepository repository;

  UpdateUserUseCase({required this.repository});

  @override
  Future<Either<Failure, User>> call(User user) {
    return repository.updateUser(user);
  }
}
