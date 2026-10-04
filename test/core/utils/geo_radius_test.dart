import 'package:book_bridge/core/utils/geo_radius.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Pt = ({String id, double? lat, double? lng});

// Buea town centre.
const _originLat = 4.1527;
const _originLng = 9.2410;

List<_Pt> _filter(List<_Pt> items, double? km) => filterWithinRadius<_Pt>(
  items: items,
  originLat: _originLat,
  originLng: _originLng,
  radiusKm: km,
  latOf: (p) => p.lat,
  lngOf: (p) => p.lng,
);

void main() {
  group('distanceInMeters', () {
    test('is zero for identical points', () {
      expect(distanceInMeters(1, 2, 1, 2), 0);
    });

    test('one degree of latitude is roughly 111 km', () {
      final d = distanceInMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 50));
    });

    test('Buea to Douala is roughly 45-55 km', () {
      final d = distanceInMeters(_originLat, _originLng, 4.0511, 9.7679);
      expect(d / 1000, inInclusiveRange(45, 60));
    });
  });

  group('filterWithinRadius', () {
    const near = (id: 'near', lat: 4.1567, lng: 9.2410); // ~0.45 km
    const mid = (id: 'mid', lat: 4.1800, lng: 9.2410); // ~3 km
    const far = (id: 'far', lat: 4.0511, lng: 9.7679); // Douala
    const noCoords = (id: 'none', lat: null, lng: null);
    final items = <_Pt>[far, near, noCoords, mid];

    test('returns items unchanged when radius is null ("Any")', () {
      expect(_filter(items, null), same(items));
    });

    test('returns items unchanged when origin is unknown', () {
      final result = filterWithinRadius<_Pt>(
        items: items,
        originLat: null,
        originLng: _originLng,
        radiusKm: 1,
        latOf: (p) => p.lat,
        lngOf: (p) => p.lng,
      );
      expect(result, same(items));
    });

    test('keeps only items inside the radius, preserving order', () {
      expect(_filter(items, 5).map((p) => p.id), ['near', 'mid']);
      expect(_filter(items, 1).map((p) => p.id), ['near']);
    });

    test('drops items without coordinates when a radius is active', () {
      expect(_filter(items, 1000).map((p) => p.id), ['far', 'near', 'mid']);
    });
  });

  test('presets are 1, 2, 5 and 10 km', () {
    expect(kRadiusPresetsKm, [1, 2, 5, 10]);
  });
}
