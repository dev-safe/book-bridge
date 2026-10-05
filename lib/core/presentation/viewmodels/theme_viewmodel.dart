import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ViewModel responsible for managing the application's theme mode.
///
/// The selected mode is persisted so it survives app restarts. Defaults to
/// following the system setting.
class ThemeViewModel extends ChangeNotifier {
  static const String prefsKey = 'theme_mode';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  ThemeViewModel({SharedPreferences? prefs})
    : _prefs = prefs,
      _themeMode = _decode(prefs?.getString(prefsKey));

  /// The current theme mode of the application.
  ThemeMode get themeMode => _themeMode;

  /// Updates the theme mode, persists it and notifies listeners.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _prefs?.setString(prefsKey, mode.name);
  }

  /// Toggles between light and dark mode.
  void toggleTheme() {
    setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  static ThemeMode _decode(String? value) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
