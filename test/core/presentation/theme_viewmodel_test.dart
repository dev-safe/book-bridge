import 'package:book_bridge/core/presentation/viewmodels/theme_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to system when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final vm = ThemeViewModel(prefs: await SharedPreferences.getInstance());
    expect(vm.themeMode, ThemeMode.system);
  });

  test('loads the saved mode', () async {
    SharedPreferences.setMockInitialValues({ThemeViewModel.prefsKey: 'dark'});
    final vm = ThemeViewModel(prefs: await SharedPreferences.getInstance());
    expect(vm.themeMode, ThemeMode.dark);
  });

  test('falls back to system for an unknown saved value', () async {
    SharedPreferences.setMockInitialValues({ThemeViewModel.prefsKey: 'neon'});
    final vm = ThemeViewModel(prefs: await SharedPreferences.getInstance());
    expect(vm.themeMode, ThemeMode.system);
  });

  test('setThemeMode notifies and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vm = ThemeViewModel(prefs: prefs);
    var notified = 0;
    vm.addListener(() => notified++);

    vm.setThemeMode(ThemeMode.light);

    expect(vm.themeMode, ThemeMode.light);
    expect(notified, 1);
    expect(prefs.getString(ThemeViewModel.prefsKey), 'light');
  });

  test('toggleTheme switches between light and dark', () async {
    SharedPreferences.setMockInitialValues({ThemeViewModel.prefsKey: 'light'});
    final vm = ThemeViewModel(prefs: await SharedPreferences.getInstance());
    vm.toggleTheme();
    expect(vm.themeMode, ThemeMode.dark);
    vm.toggleTheme();
    expect(vm.themeMode, ThemeMode.light);
  });
}
