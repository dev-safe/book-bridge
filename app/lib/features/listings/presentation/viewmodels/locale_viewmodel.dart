import 'package:flutter/material.dart';

class LocaleViewModel extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
    }
  }

  void toggleLocale() {
    if (_locale.languageCode == 'en') {
      _locale = const Locale('fr');
    } else {
      _locale = const Locale('en');
    }
    notifyListeners();
  }
}
