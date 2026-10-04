import 'package:book_bridge/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseJson = <String, dynamic>{
    'id': 'user-1',
    'email': 'student@example.com',
    'full_name': 'Test Student',
    'created_at': '2026-10-01T00:00:00.000Z',
  };

  group('UserModel school_id', () {
    test('fromJson reads school_id', () {
      final model = UserModel.fromJson({...baseJson, 'school_id': 'sch-1'});

      expect(model.schoolId, 'sch-1');
    });

    test('fromJson leaves schoolId null when absent', () {
      final model = UserModel.fromJson(baseJson);

      expect(model.schoolId, isNull);
    });

    test('toJson writes school_id', () {
      final model = UserModel.fromJson({...baseJson, 'school_id': 'sch-1'});

      expect(model.toJson()['school_id'], 'sch-1');
    });

    test('entity round-trip keeps schoolId', () {
      final model = UserModel.fromJson({...baseJson, 'school_id': 'sch-1'});

      final restored = UserModel.fromEntity(model.toEntity());

      expect(restored.schoolId, 'sch-1');
    });

    test('copyWith clearSchool removes the school', () {
      final user = UserModel.fromJson({
        ...baseJson,
        'school_id': 'sch-1',
      }).toEntity();

      expect(user.copyWith(clearSchool: true).schoolId, isNull);
      expect(user.copyWith(schoolId: 'sch-2').schoolId, 'sch-2');
      expect(user.copyWith().schoolId, 'sch-1');
    });
  });
}
