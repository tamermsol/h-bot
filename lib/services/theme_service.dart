import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  // Dark mode only — approved design is dark-only
  ThemeMode get themeMode => ThemeMode.dark;
  bool get isDarkMode => true;
  bool get isLightMode => false;

  Future<void> setThemeMode(ThemeMode mode) async {
    // No-op: dark mode only
  }

  Future<void> toggleTheme() async {
    // No-op: dark mode only
  }
}
