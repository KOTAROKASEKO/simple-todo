import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts light/dark theme for the whole app.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  static const String _prefKey = 'app_dark_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_prefKey) ?? false;
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
