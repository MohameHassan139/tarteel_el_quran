import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF10565B);       // Beautiful Deep Teal/Turquoise
  static const Color accent = Color(0xFFE4C385);        // Soft Warm Gold
  static const Color accentLight = Color(0xFFF5E6CA);   // Lighter Gold for subtle highlights

  // Light Mode Theme Colors
  static const Color bgLight = Color(0xFFF5FAF9);       // Pale teal-tinted off-white
  static const Color cardLight = Color(0xFFEBF3F2);     // Soft teal card background
  static const Color secondaryLight = Color(0xFFDDF0ED); // Secondary helper color in light mode

  // Dark Mode Theme Colors
  static const Color bgDark = Color(0xFF0A1415);        // Deep dark slate-teal background
  static const Color cardDark = Color(0xFF132022);      // Deep slate-teal card background
  static const Color secondaryDark = Color(0xFF1D3134);  // Deep secondary card background

  // Context-aware convenience colors (based on brightness)
  static Color getPrimary(bool isDark) => primary;
  static Color getBackground(bool isDark) => isDark ? bgDark : bgLight;
  static Color getCard(bool isDark) => isDark ? cardDark : cardLight;
  static Color getSecondary(bool isDark) => isDark ? secondaryDark : secondaryLight;
}
