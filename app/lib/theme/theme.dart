import 'package:flutter/material.dart';

/// Colors and text theme lifted from the HTML prototype, so the real app
/// looks like a continuation of it rather than a generic Material app.
class ConvoyColors {
  static const road = Color(0xFF0E1115);
  static const panel = Color(0xFF161B21);
  static const panel2 = Color(0xFF1E252D);
  static const paint = Color(0xFFEDE8DA);
  static const muted = Color(0xFF8B95A1);
  static const amber = Color(0xFFF5A623);
  static const signal = Color(0xFF3FD09A);
  static const alert = Color(0xFFFF6152);
  static const stroke = Color(0x1EEDE8DA);
}

ThemeData buildConvoyTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: ConvoyColors.road,
    colorScheme: base.colorScheme.copyWith(
      primary: ConvoyColors.amber,
      surface: ConvoyColors.panel,
      onSurface: ConvoyColors.paint,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ConvoyColors.road,
      elevation: 0,
      foregroundColor: ConvoyColors.paint,
    ),
    cardTheme: CardThemeData(
      color: ConvoyColors.panel2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ConvoyColors.stroke),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ConvoyColors.amber,
        foregroundColor: const Color(0xFF14110A),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ConvoyColors.paint,
        side: const BorderSide(color: ConvoyColors.stroke),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ConvoyColors.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ConvoyColors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ConvoyColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ConvoyColors.amber),
      ),
      hintStyle: const TextStyle(color: Color(0xFF5D6672)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ConvoyColors.panel2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ConvoyColors.stroke, width: 1),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 17.5,
        fontWeight: FontWeight.w700,
        color: ConvoyColors.paint,
        letterSpacing: -0.2,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 13.5,
        color: ConvoyColors.muted,
        height: 1.45,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
  );
}
