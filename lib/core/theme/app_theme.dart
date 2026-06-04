import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg          = Color(0xFF04080D);
  static const surface     = Color(0xFF090F18);
  static const surface2    = Color(0xFF0D1620);
  static const cyan        = Color(0xFF00D2FF);
  static const green       = Color(0xFF00FFB3);
  static const amber       = Color(0xFFFFC240);
  static const red         = Color(0xFFFF5470);
  static const purple      = Color(0xFFA78BFA);
  static const textPrimary = Color(0xFFDDEEFF);
  static const textMuted   = Color(0xFF4A6A8A);
  static const cardBorder  = Color(0xFF0D2030);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.green,
      surface: AppColors.surface,
    ),
    textTheme: GoogleFonts.syneTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Syne',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: GoogleFonts.spaceMono(fontSize: 12),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.cyan,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}

// Keep the old function in case anything still calls it
ThemeData buildAppTheme() => AppTheme.dark;