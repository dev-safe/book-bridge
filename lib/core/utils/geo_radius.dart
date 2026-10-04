import 'dart:math' as math;

/// Preset search radii (in kilometres) offered in the distance filter.
const List<double> kRadiusPresetsKm = [1, 2, 5, 10];

const double _earthRadiusMeters = 6371000;

/// Great-circle distance in metres between two coordinates (haversine).
double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
}

/// Returns the items within [radiusKm] of the origin, preserving order.
///
/// When [radiusKm] is null ("Any") or the origin is unknown, [items] is
/// returned unchanged. Items without coordinates are excluded whenever a
/// radius is active, since their distance cannot be verified.
List<T> filterWithinRadius<T>({
  required List<T> items,
  required double? originLat,
  required double? originLng,
  required double? radiusKm,
  required double? Function(T) latOf,
  required double? Function(T) lngOf,
}) {
  if (radiusKm == null || originLat == null || originLng == null) {
    return items;
  }
  final maxMeters = radiusKm * 1000;
  return items.where((item) {
    final lat = latOf(item);
    final lng = lngOf(item);
    if (lat == null || lng == null) return false;
    return distanceInMeters(originLat, originLng, lat, lng) <= maxMeters;
  }).toList();
}

double _toRadians(double degrees) => degrees * math.pi / 180;
