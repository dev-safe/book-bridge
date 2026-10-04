import 'package:book_bridge/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseJson = <String, dynamic>{
    'id': 'user-1',
    'email': 'student@example.com',
    'full_name': 'Test Student',
    'created_at': '2026-10-01T00:00:00.000Z',
  };

  group('UserModel age declaration', () {
    test('is absent when columns are missing', () {
      final model = UserModel.fromJson(baseJson);

      expect(model.ageDeclaration, isNull);
      expect(model.ageDeclaredAt, isNull);
      expect(model.hasAgeDeclaration, isFalse);
    });

    test('parses guardian declaration and timestamp', () {
      final model = UserModel.fromJson({
        ...baseJson,
        'age_declaration': 'guardian',
        'age_declared_at': '2026-10-13T08:30:00.000Z',
      });

      expect(model.ageDeclaration, 'guardian');
      expect(model.ageDeclaredAt, DateTime.utc(2026, 10, 13, 8, 30));
      expect(model.hasAgeDeclaration, isTrue);
    });

    test('toJson writes both fields', () {
      final json = UserModel.fromJson({
        ...baseJson,
        'age_declaration': 'adult',
        'age_declared_at': '2026-10-13T08:30:00.000Z',
      }).toJson();

      expect(json['age_declaration'], 'adult');
      expect(
        DateTime.parse(json['age_declared_at'] as String),
        DateTime.utc(2026, 10, 13, 8, 30),
      );
    });

    test('entity round-trip keeps declaration', () {
      final model = UserModel.fromJson({
        ...baseJson,
        'age_declaration': 'adult',
        'age_declared_at': '2026-10-13T08:30:00.000Z',
      });

      final roundTrip = UserModel.fromEntity(model.toEntity());

      expect(roundTrip.ageDeclaration, 'adult');
      expect(roundTrip.ageDeclaredAt, model.ageDeclaredAt);
    });

    test('copyWith sets declaration on undeclared user', () {
      final entity = UserModel.fromJson(baseJson).toEntity();
      final declared = entity.copyWith(
        ageDeclaration: 'adult',
        ageDeclaredAt: DateTime.utc(2026, 10, 13),
      );

      expect(entity.hasAgeDeclaration, isFalse);
      expect(declared.hasAgeDeclaration, isTrue);
      expect(declared.ageDeclaration, 'adult');
    });
  });
}
