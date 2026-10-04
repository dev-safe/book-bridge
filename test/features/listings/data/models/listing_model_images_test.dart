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

  group('ListingModel images', () {
    test('fromJson reads image_urls in order', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'image_urls': [
          'https://cdn.example.com/a.jpg',
          'https://cdn.example.com/b.jpg',
        ],
      });

      expect(model.imageUrls, [
        'https://cdn.example.com/a.jpg',
        'https://cdn.example.com/b.jpg',
      ]);
      expect(model.gallery, model.imageUrls);
    });

    test('fromJson drops empty and non-string entries', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'image_urls': ['', 'https://cdn.example.com/b.jpg', null, 3],
      });

      expect(model.imageUrls, ['https://cdn.example.com/b.jpg']);
    });

    test('legacy rows without image_urls fall back to the cover', () {
      final model = ListingModel.fromJson(baseJson);

      expect(model.imageUrls, isEmpty);
      expect(model.gallery, ['https://cdn.example.com/a.jpg']);
    });

    test('gallery is empty when there is no photo at all', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'image_url': '',
        'image_urls': null,
      });

      expect(model.gallery, isEmpty);
    });

    test('toJson round-trips image_urls', () {
      final model = ListingModel.fromJson({
        ...baseJson,
        'image_urls': [
          'https://cdn.example.com/a.jpg',
          'https://cdn.example.com/b.jpg',
        ],
      });

      final json = model.toJson();

      expect(json['image_urls'], model.imageUrls);
      expect(ListingModel.fromJson(json), model);
    });
  });
}
