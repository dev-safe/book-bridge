import 'package:geolocator/geolocator.dart';

/// Why the app can or cannot read the device location.
enum LocationAccessStatus {
  unknown,
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

/// Thin seam over [Geolocator] so location flows can be unit tested.
abstract class LocationAccess {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> currentPosition();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class GeolocatorLocationAccess implements LocationAccess {
  const GeolocatorLocationAccess();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> currentPosition() => Geolocator.getCurrentPosition();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
