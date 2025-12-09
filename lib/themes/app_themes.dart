import 'package:flutter/material.dart';
import 'dart:math';

// A simple class to hold our gradient colors
class GradientTheme {
  final Color startColor;
  final Color endColor;

  const GradientTheme({required this.startColor, required this.endColor});
}

// A list of predefined gradient themes
final List<GradientTheme> appThemes = [
  // Original Purple/Blue
  const GradientTheme(
      startColor: Color(0xFF6A1B9A), endColor: Color(0xFF303F9F)),
  // Fiery Sunset
  const GradientTheme(
      startColor: Color(0xFFd31027), endColor: Color(0xFFea384d)),
  // Lush Jungle
  const GradientTheme(
      startColor: Color(0xFF11998e), endColor: Color(0xFF38ef7d)),
  // Cosmic Fusion
  const GradientTheme(
      startColor: Color(0xFF480048), endColor: Color(0xFF004e92)),
  // Royal Gold
  const GradientTheme(
      startColor: Color(0xFF1f1c2c), endColor: Color(0xFF928dab)),
  // Emerald Sea
  const GradientTheme(
      startColor: Color(0xFF00b09b), endColor: Color(0xFF96c93d)),
  // Ruby Passion
  const GradientTheme(
      startColor: Color(0xFFdd1818), endColor: Color(0xFF333333)),
  // Cyberpunk Neon
  const GradientTheme(
      startColor: Color(0xFFF000FF), endColor: Color(0xFF00C2FF)),
  // Deep Space
  const GradientTheme(
      startColor: Color(0xFF263238), endColor: Color(0xFF000000)),
];

// A static manager to hold the currently selected theme
class ThemeManager {
  static bool _initialized = false;
  static late GradientTheme currentTheme;

  static void initialize() {
    if (!_initialized) {
      final random = Random();
      currentTheme = appThemes[random.nextInt(appThemes.length)];
      _initialized = true;
    }
  }
}
