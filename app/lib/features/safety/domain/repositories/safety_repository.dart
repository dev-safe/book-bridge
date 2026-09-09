import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';

/// Abstract interface for the safety feature's data access.
abstract class SafetyRepository {
  Future<Either<Failure, List<CampusZone>>> getCampusZones();
}
