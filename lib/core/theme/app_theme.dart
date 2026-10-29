import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = _buildLightTheme();
  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    const bg = Color(0xFFF6F7F9);
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFE5E7EB);
    const primary = Color(0xFF18181B);
    const accent = Color(0xFF2563EB);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Morabba',
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        surface: surface,
        onSurface: Color(0xFF111827),
        onSurfaceVariant: Color(0xFF6B7280),
        outline: border,
        outlineVariant: Color(0xFFE5E7EB),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    const bg = Color(0xFF0A0D12);
    const surface = Color(0xFF121721);
    const border = Color(0xFF1E2636);
    const primary = Color(0xFFF3F4F6);
    const accent = Color(0xFF3B82F6);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Morabba',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF0A0D12),
        secondary: accent,
        surface: surface,
        onSurface: Color(0xFFF3F4F6),
        onSurfaceVariant: Color(0xFF9CA3AF),
        outline: border,
        outlineVariant: Color(0xFF1E2636),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Color(0xFFF3F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
