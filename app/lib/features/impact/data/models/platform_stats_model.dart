import 'package:book_bridge/features/impact/domain/entities/platform_stats.dart';

class PlatformStatsModel extends PlatformStats {
  const PlatformStatsModel({
    required super.totalBooksCirculated,
    required super.totalStudentsReached,
    required super.totalMoneySavedFcfa,
    required super.totalCo2AvoidedKg,
  });

  factory PlatformStatsModel.fromJson(Map<String, dynamic> json) {
    return PlatformStatsModel(
      totalBooksCirculated: json['total_books_circulated'] as int? ?? 0,
      totalStudentsReached: json['total_students_reached'] as int? ?? 0,
      totalMoneySavedFcfa: (json['total_money_saved_fcfa'] as num? ?? 0)
          .toInt(),
      totalCo2AvoidedKg: (json['total_co2_avoided_kg'] as num? ?? 0.0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_books_circulated': totalBooksCirculated,
      'total_students_reached': totalStudentsReached,
      'total_money_saved_fcfa': totalMoneySavedFcfa,
      'total_co2_avoided_kg': totalCo2AvoidedKg,
    };
  }
}
