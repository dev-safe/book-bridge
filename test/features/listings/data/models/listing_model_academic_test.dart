import 'package:book_bridge/features/listings/data/models/listing_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseJson = <String, dynamic>{
    'id': 'listing-1',
    'title': 'Physics for Form 5',
    'author': 'Author',
    'price_fcfa': 2500,
    'condition': 'good',
    'image_url': 'https://cdn.example.com/a.jpg',
    'description': '',
    'seller_id': 'seller-1',
    'status': 'available',
    'created_at': '2026-10-01T00:00:00.000Z',
  };

  group('ListingModel academic fields', () {
    test('fromJson reads ids and embedded labels', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'class_level_id': 'cl-1',
        'subject_id': 'sub-1',
        'school_id': 'sch-1',
        'class_level': {'label': 'Form 5'},
        'subject': {'name': 'Physics'},
        'school': {'name': 'GBHS Molyko'},
      });

      expect(model.classLevelId, 'cl-1');
      expect(model.classLevelLabel, 'Form 5');
      expect(model.subjectId, 'sub-1');
      expect(model.subjectName, 'Physics');
      expect(model.schoolId, 'sch-1');
      expect(model.schoolName, 'GBHS Molyko');
    });

    test('fromJson tolerates missing or null embeds', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'class_level_id': 'cl-1',
        'class_level': null,
      });

      expect(model.classLevelId, 'cl-1');
      expect(model.classLevelLabel, isNull);
      expect(model.subjectId, isNull);
      expect(model.subjectName, isNull);
      expect(model.schoolId, isNull);
      expect(model.schoolName, isNull);
    });

    test('toJson writes ids but not display labels', () {
      final json = ListingModel.fromJson({
        ...baseJson,
        'class_level_id': 'cl-1',
        'subject_id': 'sub-1',
        'school_id': 'sch-1',
        'class_level': {'label': 'Form 5'},
      }).toJson();

      expect(json['class_level_id'], 'cl-1');
      expect(json['subject_id'], 'sub-1');
      expect(json['school_id'], 'sch-1');
      expect(json.containsKey('class_level'), isFalse);
      expect(json.containsKey('subject'), isFalse);
      expect(json.containsKey('school'), isFalse);
    });

    test('entity round-trip keeps ids and labels', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'class_level_id': 'cl-1',
        'subject_id': 'sub-1',
        'school_id': 'sch-1',
        'class_level': {'label': 'Form 5'},
        'subject': {'name': 'Physics'},
        'school': {'name': 'GBHS Molyko'},
      });

      final restored = ListingModel.fromEntity(model.toEntity());

      expect(restored.classLevelId, 'cl-1');
      expect(restored.classLevelLabel, 'Form 5');
      expect(restored.subjectId, 'sub-1');
      expect(restored.subjectName, 'Physics');
      expect(restored.schoolId, 'sch-1');
      expect(restored.schoolName, 'GBHS Molyko');
    });
  });
}
