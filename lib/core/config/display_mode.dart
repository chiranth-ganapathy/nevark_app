import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beginner vs professional stock/sector presentation (UI only), and theme mode.
class DisplayMode {
  DisplayMode._();

  static const _prefKey = 'pref_display_mode';
  static const _themePrefKey = 'pref_theme_mode';

  static final ValueNotifier<bool> isProfessional = ValueNotifier(false);
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isProfessional.value =
        prefs.getString(_prefKey) == 'professional';
  }

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_themePrefKey);
    if (modeStr == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else if (modeStr == 'light') {
      themeMode.value = ThemeMode.light;
    } else {
      themeMode.value = ThemeMode.system;
    }
  }

  static Future<void> setProfessional(bool value) async {
    isProfessional.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      value ? 'professional' : 'beginner',
    );
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, mode.name);
  }

  static Future<void> toggle() => setProfessional(!isProfessional.value);
}
