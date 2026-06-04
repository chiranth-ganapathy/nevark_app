import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';
import 'core/config/display_mode.dart';
import 'services/alerts/alert_monitor.dart';
import 'services/alerts/alert_store.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs          = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  await DisplayMode.load();
  await AlertStore.instance.load();

  // Show UI immediately — market engine starts in background
  runApp(
    ProviderScope(
      child: NeVarkApp(seenOnboarding: seenOnboarding),
    ),
  );

  ApiService.init();
  AlertMonitor.instance.start();
}

class NeVarkApp extends StatelessWidget {
  final bool seenOnboarding;
  const NeVarkApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeVark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: SplashScreen(seenOnboarding: seenOnboarding),
      themeAnimationDuration: const Duration(milliseconds: 280),
      themeAnimationCurve: Curves.easeOutCubic,
    );
  }
}