import 'package:equatable/equatable.dart';

/// Domain entity representing a verified safe campus exchange zone.
class CampusZone extends Equatable {
  final String id;
  final String name;
  final String university;
  final String city;
  final String? description;
  final double latitude;
  final double longitude;
  final bool isVerified;

  const CampusZone({
    required this.id,
    required this.name,
    required this.university,
    required this.city,
    this.description,
    required this.latitude,
    required this.longitude,
    this.isVerified = false,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    university,
    city,
    description,
    latitude,
    longitude,
    isVerified,
  ];
}
