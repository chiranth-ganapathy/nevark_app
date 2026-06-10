import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/display_mode.dart';

class AppColors {
  static bool get _isDark {
    final mode = DisplayMode.themeMode.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  static Color get bg          => _isDark ? const Color(0xFF04080D) : const Color(0xFFF3F6F9);
  static Color get surface     => _isDark ? const Color(0xFF090F18) : const Color(0xFFFFFFFF);
  static Color get surface2    => _isDark ? const Color(0xFF0D1620) : const Color(0xFFE9EFF5);
  static Color get cyan        => _isDark ? const Color(0xFF00D2FF) : const Color(0xFF009ABF);
  static Color get green       => _isDark ? const Color(0xFF00FFB3) : const Color(0xFF00A372);
  static Color get amber       => _isDark ? const Color(0xFFFFC240) : const Color(0xFFD97706);
  static Color get red         => _isDark ? const Color(0xFFFF5470) : const Color(0xFFDC2626);
  static Color get purple      => _isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get textPrimary => _isDark ? const Color(0xFFDDEEFF) : const Color(0xFF1E293B);
  static Color get textMuted   => _isDark ? const Color(0xFF4A6A8A) : const Color(0xFF64748B);
  static Color get cardBorder  => _isDark ? const Color(0xFF0D2030) : const Color(0xFFE2E8F0);
}

class AppTheme {
  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF00D2FF) : const Color(0xFF009ABF);
    final secondaryColor = isDark ? const Color(0xFF00FFB3) : const Color(0xFF00A372);
    final bgColor = isDark ? const Color(0xFF04080D) : const Color(0xFFF3F6F9);
    final surfaceColor = isDark ? const Color(0xFF090F18) : const Color(0xFFFFFFFF);
    final textPrimaryColor = isDark ? const Color(0xFFDDEEFF) : const Color(0xFF1E293B);
    final textMutedColor = isDark ? const Color(0xFF4A6A8A) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF0D2030) : const Color(0xFFE2E8F0);

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryColor,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: isDark ? const Color(0xFFFF5470) : const Color(0xFFDC2626),
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
      ),
      textTheme: GoogleFonts.syneTextTheme().apply(
        bodyColor: textPrimaryColor,
        displayColor: isDark ? Colors.white : Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          fontFamily: 'Syne',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: GoogleFonts.spaceMono(fontSize: 12, color: textPrimaryColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMutedColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

// Keep the old function in case anything still calls it
ThemeData buildAppTheme() => AppTheme.dark;