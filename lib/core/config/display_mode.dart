import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beginner vs professional stock/sector presentation (UI only).
class DisplayMode {
  DisplayMode._();

  static const _prefKey = 'pref_display_mode';

  static final ValueNotifier<bool> isProfessional = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isProfessional.value =
        prefs.getString(_prefKey) == 'professional';
  }

  static Future<void> setProfessional(bool value) async {
    isProfessional.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      value ? 'professional' : 'beginner',
    );
  }

  static Future<void> toggle() => setProfessional(!isProfessional.value);
}
