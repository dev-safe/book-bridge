import 'package:book_bridge/features/safety/domain/entities/campus_zone.dart';

/// Data model for [CampusZone] with JSON serialization from Supabase.
class CampusZoneModel extends CampusZone {
  const CampusZoneModel({
    required super.id,
    required super.name,
    required super.university,
    required super.city,
    super.description,
    required super.latitude,
    required super.longitude,
    super.isVerified,
  });

  factory CampusZoneModel.fromJson(Map<String, dynamic> json) {
    return CampusZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      university: json['university'] as String,
      city: json['city'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'university': university,
      'city': city,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'is_verified': isVerified,
    };
  }
}
