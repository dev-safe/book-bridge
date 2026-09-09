import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:book_bridge/core/error/failures.dart';
import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';
import 'package:book_bridge/features/impact/domain/repositories/impact_repository.dart';
import 'package:book_bridge/features/impact/data/datasources/supabase_impact_data_source.dart';
import 'package:book_bridge/features/impact/data/models/platform_stats_model.dart';

const String _kPlatformStatsCacheKey = 'cached_platform_impact_stats';

class ImpactRepositoryImpl implements ImpactRepository {
  final SupabaseImpactDataSource dataSource;
  final SharedPreferences sharedPreferences;

  ImpactRepositoryImpl({
    required this.dataSource,
    required this.sharedPreferences,
  });

  @override
  Future<Either<Failure, PlatformStats>> getPlatformStats() async {
    try {
      final remoteStats = await dataSource.getPlatformStats();
      // Cache locally
      await sharedPreferences.setString(
        _kPlatformStatsCacheKey,
        jsonEncode(remoteStats.toJson()),
      );
      return Right(remoteStats);
    } catch (_) {
      // Fallback to cache offline
      final cachedStr = sharedPreferences.getString(_kPlatformStatsCacheKey);
      if (cachedStr != null) {
        try {
          final decoded = jsonDecode(cachedStr) as Map<String, dynamic>;
          return Right(PlatformStatsModel.fromJson(decoded));
        } catch (_) {}
      }
      return Left(
        const ServerFailure(
          message:
              'Failed to retrieve social impact stats from cache or server.',
        ),
      );
    }
  }
}
