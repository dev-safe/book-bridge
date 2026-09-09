import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';

abstract class ImpactRepository {
  Future<Either<Failure, PlatformStats>> getPlatformStats();
}
