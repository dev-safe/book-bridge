import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';
import 'package:book_bridge/features/safety/domain/repositories/safety_repository.dart';

/// Use case to retrieve all verified campus meetup zones.
class GetCampusZonesUseCase {
  final SafetyRepository repository;

  GetCampusZonesUseCase(this.repository);

  Future<Either<Failure, List<CampusZone>>> call() async {
    return await repository.getCampusZones();
  }
}
