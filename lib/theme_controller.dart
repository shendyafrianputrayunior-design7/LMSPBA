import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setDarkMode(bool value) {
    final newMode = value ? ThemeMode.dark : ThemeMode.light;

    if (_themeMode == newMode) return;

    _themeMode = newMode;
    notifyListeners();
  }
}