import 'package:equatable/equatable.dart';

/// A class level from the seeded `class_levels` lookup table (e.g. "Form 3").
class ClassLevel extends Equatable {
  final String id;
  final String system;
  final String code;
  final String label;

  const ClassLevel({
    required this.id,
    required this.system,
    required this.code,
    required this.label,
  });

  factory ClassLevel.fromJson(Map<String, dynamic> json) => ClassLevel(
    id: json['id'] as String,
    system: json['system'] as String? ?? '',
    code: json['code'] as String? ?? '',
    label: json['label'] as String? ?? '',
  );

  @override
  List<Object?> get props => [id, system, code, label];
}

/// A school subject from the seeded `subjects` lookup table.
class Subject extends Equatable {
  final String id;
  final String code;
  final String name;

  const Subject({required this.id, required this.code, required this.name});

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  @override
  List<Object?> get props => [id, code, name];
}

/// A school from the admin-curated `schools` lookup table.
class School extends Equatable {
  final String id;
  final String name;
  final String? town;
  final String? region;

  const School({required this.id, required this.name, this.town, this.region});

  factory School.fromJson(Map<String, dynamic> json) => School(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    town: json['town'] as String?,
    region: json['region'] as String?,
  );

  /// Name with town appended when known, for disambiguation in pickers.
  String get displayName =>
      (town == null || town!.isEmpty) ? name : '$name, $town';

  @override
  List<Object?> get props => [id, name, town, region];
}

/// Optional academic filters applied to listing queries.
class AcademicFilters extends Equatable {
  final String? classLevelId;
  final String? subjectId;
  final String? schoolId;

  const AcademicFilters({this.classLevelId, this.subjectId, this.schoolId});

  static const none = AcademicFilters();

  bool get isEmpty =>
      classLevelId == null && subjectId == null && schoolId == null;

  @override
  List<Object?> get props => [classLevelId, subjectId, schoolId];
}
