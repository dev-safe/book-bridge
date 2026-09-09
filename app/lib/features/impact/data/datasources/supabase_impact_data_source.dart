import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/features/impact/data/models/platform_stats_model.dart';

class SupabaseImpactDataSource {
  final SupabaseClient supabaseClient;

  SupabaseImpactDataSource({required this.supabaseClient});

  Future<PlatformStatsModel> getPlatformStats() async {
    final response = await supabaseClient
        .from('platform_stats')
        .select()
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return const PlatformStatsModel(
        totalBooksCirculated: 0,
        totalStudentsReached: 0,
        totalMoneySavedFcfa: 0,
        totalCo2AvoidedKg: 0.0,
      );
    }
    return PlatformStatsModel.fromJson(response);
  }
}
