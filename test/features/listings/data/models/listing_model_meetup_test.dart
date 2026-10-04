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

  group('ListingModel meetup fields', () {
    test('fromJson reads spot and pin, accepting int coordinates', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'meetup_spot': 'UB Main Gate',
        'meetup_latitude': 4.152,
        'meetup_longitude': 9,
      });

      expect(model.meetupSpot, 'UB Main Gate');
      expect(model.meetupLatitude, 4.152);
      expect(model.meetupLongitude, 9.0);
      expect(model.hasMeetupPin, isTrue);
    });

    test('fromJson leaves meetup empty when columns are absent', () {
      final model = ListingModel.fromJson(baseJson);

      expect(model.meetupSpot, isNull);
      expect(model.meetupLatitude, isNull);
      expect(model.meetupLongitude, isNull);
      expect(model.hasMeetupPin, isFalse);
    });

    test('toJson writes the meetup columns', () {
      final json = ListingModel.fromJson({
        ...baseJson,
        'meetup_spot': 'Molyko junction',
        'meetup_latitude': 4.15,
        'meetup_longitude': 9.29,
      }).toJson();

      expect(json['meetup_spot'], 'Molyko junction');
      expect(json['meetup_latitude'], 4.15);
      expect(json['meetup_longitude'], 9.29);
    });

    test('fromEntity and toEntity keep the meetup fields', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'meetup_spot': 'Library',
        'meetup_latitude': 4.1,
        'meetup_longitude': 9.2,
      });

      final entity = ListingModel.fromEntity(model.toEntity()).toEntity();

      expect(entity.meetupSpot, 'Library');
      expect(entity.meetupLatitude, 4.1);
      expect(entity.meetupLongitude, 9.2);
    });
  });
}
