import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocationEnabledKey = 'location_enabled';

/// ViewModel that manages the user's in-app location preference.
///
/// Persists the on/off toggle via SharedPreferences so the setting
/// survives app restarts. Other ViewModels (HomeViewModel, SellViewModel)
/// should check [locationEnabled] before requesting GPS.
class LocationViewModel extends ChangeNotifier {
  bool _locationEnabled;

  LocationViewModel({bool initialValue = true})
    : _locationEnabled = initialValue;

  bool get locationEnabled => _locationEnabled;

  /// Toggles the location preference and persists the new value.
  Future<void> toggle() async {
    _locationEnabled = !_locationEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationEnabledKey, _locationEnabled);
  }

  /// Sets location preference explicitly and persists it.
  Future<void> setEnabled(bool value) async {
    if (_locationEnabled == value) return;
    _locationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationEnabledKey, _locationEnabled);
  }

  /// Loads the persisted preference from disk.
  /// Call this once during app startup (before providing to widget tree).
  static Future<LocationViewModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true (enabled) on first install.
    final enabled = prefs.getBool(_kLocationEnabledKey) ?? true;
    return LocationViewModel(initialValue: enabled);
  }
}
