import 'package:flutter/material.dart';

class ArcoTheme {
  static ThemeData get dark {
    const seed = Color(0xFF7357FF);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: const Color(0xFF171821),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0F14),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF12131A),
        indicatorColor: Color(0x337357FF),
      ),
      useMaterial3: true,
    );
  }
}
