import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  Color get backgroundColor =>
      _isDarkMode ? const Color(0xFF121212) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : Colors.black;
  Color get primaryColor => const Color(0xFF2296F3);
  Color get secondaryTextColor =>
      _isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
  Color get cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get shadowColor => _isDarkMode ? Colors.white24 : Colors.black12;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
