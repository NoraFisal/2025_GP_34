import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF0E141B);
  static const Color card = Color(0xFF1E242B);
  static const Color cardDeep = Color(0xFF192028);
  static const Color pill = Color(0xFF2A3139);
  static const Color accent = Color(0xFFD64A3A);
  static const Color textSecondary = Colors.white70;
}

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
    primary: AppColors.accent,
    surface: AppColors.bg,
    background: AppColors.bg,
  ),
  scaffoldBackgroundColor: AppColors.bg,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      elevation: 4,
    ),
  ),
);
