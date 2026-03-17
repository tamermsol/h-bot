import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'app_locale';
  static const String _defaultLocale = 'en';
  static const List<String> supportedLocales = ['en', 'ar'];

  String _locale = _defaultLocale;

  LocaleService() {
    _loadLocale();
  }

  String get locale => _locale;
  bool get isArabic => _locale == 'ar';

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_localeKey);
      if (saved != null && supportedLocales.contains(saved)) {
        _locale = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }

  Future<void> setLocale(String langCode) async {
    if (!supportedLocales.contains(langCode)) return;
    if (_locale == langCode) return;

    _locale = langCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, langCode);
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }
}
