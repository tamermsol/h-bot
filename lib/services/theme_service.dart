import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  ThemeMode _themeMode = ThemeMode.system; // Default to system mode

  ThemeService() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme != null) {
        switch (savedTheme) {
          case 'dark': _themeMode = ThemeMode.dark; break;
          case 'system': _themeMode = ThemeMode.system; break;
          default: _themeMode = ThemeMode.light;
        }
      } else {
        // First launch - follow system theme by default
        _themeMode = ThemeMode.system;
        await _saveTheme();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
      _themeMode = ThemeMode.system; // Fallback to system mode
    }
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String value;
      switch (_themeMode) {
        case ThemeMode.dark: value = 'dark'; break;
        case ThemeMode.system: value = 'system'; break;
        default: value = 'light';
      }
      await prefs.setString(_themeKey, value);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _saveTheme();
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
