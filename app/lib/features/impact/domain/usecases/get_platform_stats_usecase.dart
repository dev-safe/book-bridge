import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/core/usecases/usecase.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';
import 'package:book_bridge/features/impact/domain/repositories/impact_repository.dart';

class GetPlatformStatsUseCase extends UseCaseNoParams<PlatformStats> {
  final ImpactRepository repository;

  GetPlatformStatsUseCase({required this.repository});

  @override
  Future<Either<Failure, PlatformStats>> call() {
    return repository.getPlatformStats();
  }
}
