import 'package:flutter/material.dart';

class LumiTheme {
  // 8-bit Pastel Palette
  static const Color pink = Color(0xFFFFB6C1);
  static const Color pinkLight = Color(0xFFFFD1DC);
  static const Color pinkPale = Color(0xFFFFF0F5);
  static const Color cream = Color(0xFFFFFEF9);
  static const Color mistyRose = Color(0xFFFFE4E1);
  static const Color skyBlue = Color(0xFFE8F4FF);
  static const Color babyBlue = Color(0xFF87CEEB);
  static const Color mint = Color(0xFF98FB98);
  static const Color mintHover = Color(0xFF90EE90);
  static const Color deepPink = Color(0xFFC71585);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF999999);

  // On-device glow colors
  static const Color electricYellow = Color(0xFFFFDC64);
  static const Color electricGold = Color(0xFFFFC832);

  // Cloud state colors
  static const Color cloudBlue = Color(0xFF64B5F6);

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DungGeunMo',
      colorScheme: ColorScheme.light(
        primary: pink,
        secondary: mint,
        surface: cream,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: mistyRose,
      appBarTheme: const AppBarTheme(
        backgroundColor: pink,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    );
  }
}
