import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:book_bridge/core/error/exceptions.dart';
import 'package:book_bridge/features/safety/data/models/campus_zone_model.dart';

/// Remote datasource that queries campus_zones from Supabase.
class SafetyRemoteDataSource {
  final SupabaseClient supabaseClient;

  SafetyRemoteDataSource({required this.supabaseClient});

  Future<List<CampusZoneModel>> getCampusZones() async {
    try {
      final response = await supabaseClient
          .from('campus_zones')
          .select()
          .order('university', ascending: true);

      return (response as List<dynamic>)
          .map((item) => CampusZoneModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
