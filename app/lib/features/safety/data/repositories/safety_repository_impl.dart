import 'package:dartz/dartz.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';
import 'package:book_bridge/features/safety/domain/repositories/safety_repository.dart';
import 'package:book_bridge/features/safety/data/datasources/safety_remote_datasource.dart';

/// Concrete implementation of [SafetyRepository] backed by Supabase.
class SafetyRepositoryImpl implements SafetyRepository {
  final SafetyRemoteDataSource remoteDataSource;

  SafetyRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CampusZone>>> getCampusZones() async {
    try {
      final models = await remoteDataSource.getCampusZones();
      return Right(models);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
