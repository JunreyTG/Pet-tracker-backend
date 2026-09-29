import 'package:flutter/material.dart';

class AppTheme {
  static const green = Color(0xFF16C36A);
  static const orange = Color(0xFFFF5A1F);
  static const ink = Color(0xFF1E293B);
  static const mist = Color(0xFFF1F5F9);
  static const darkBg = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceVariant = Color(0xFF334155);

  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: mist,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      secondary: orange,
      surface: Colors.white,
      surfaceContainerHigh: const Color(0xFFF8FAFC),
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF64748B),
      brightness: Brightness.light,
    ),
    textTheme: Typography.material2021().black.apply(
      bodyColor: ink,
      displayColor: ink,
    ).copyWith(
      headlineLarge: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: ink),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: ink),
      titleLarge: const TextStyle(fontWeight: FontWeight.w800, color: ink),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, color: ink),
      bodyLarge: const TextStyle(fontWeight: FontWeight.w500, color: ink, fontSize: 16),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400, color: ink, fontSize: 14),
      bodySmall: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: green.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? green : ink,
        ),
      ),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      secondary: orange,
      surface: darkSurface,
      surfaceContainerHigh: darkSurfaceVariant,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFF94A3B8),
      brightness: Brightness.dark,
    ),
    textTheme: Typography.material2021().white.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ).copyWith(
      headlineLarge: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white),
      titleLarge: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      bodyLarge: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
      bodyMedium: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFE2E8F0), fontSize: 14),
      bodySmall: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: green, width: 2),
      ),
      filled: true,
      fillColor: darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF475569)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: darkSurface,
      indicatorColor: green.withValues(alpha: .24),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? green : const Color(0xFF94A3B8),
        ),
      ),
    ),
  );
}
