import 'package:flutter/material.dart';

/// ViewModel responsible for managing the application's theme mode.
class ThemeViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  /// The current theme mode of the application.
  ThemeMode get themeMode => _themeMode;

  /// Updates the theme mode and notifies listeners.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Toggles between light and dark mode.
  /// If currently in system mode, it will switch to light or dark based on the platform brightness
  /// (usually handled by the system, so this is for manual overrides).
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
