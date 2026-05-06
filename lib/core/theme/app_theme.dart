import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg        = Color(0xFF04080D);
  static const surface   = Color(0xFF090F18);
  static const cyan      = Color(0xFF00D2FF);
  static const green     = Color(0xFF00FFB3);
  static const amber     = Color(0xFFFFC240);
  static const red       = Color(0xFFFF5470);
  static const textPrimary   = Color(0xFFDDEEFF);
  static const textMuted     = Color(0xFF4A6A8A);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.dark(primary: AppColors.cyan),
    textTheme: GoogleFonts.syneTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: Colors.white,
    ),
  );
}