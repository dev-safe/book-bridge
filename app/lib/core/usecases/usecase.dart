import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';

/// Abstract base class for all use cases in the application.
///
/// Use cases are the core business logic units that orchestrate
/// interactions between the presentation and data layers.
///
/// Type parameters:
/// - [ResultType]: The type of successful result returned by this use case.
/// - [Params]: The type of parameters required by this use case.
abstract class UseCase<ResultType, Params> {
  /// Executes the use case with the given parameters.
  ///
  /// Returns an [Either] containing either a [Failure] (left) or
  /// a successful result of type [ResultType] (right).
  Future<Either<Failure, ResultType>> call(Params params);
}

/// A specialized use case for operations that don't require parameters.
abstract class UseCaseNoParams<ResultType> {
  /// Executes the use case without any parameters.
  ///
  /// Returns an [Either] containing either a [Failure] (left) or
  /// a successful result of type [ResultType] (right).
  Future<Either<Failure, ResultType>> call();
}
