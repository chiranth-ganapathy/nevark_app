import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool seenOnboarding;
  const SplashScreen({super.key, required this.seenOnboarding});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    // After 2 seconds navigate to correct screen
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    if (widget.seenOnboarding) {
      // ✓ FIX: Go to AuthService (AuthGate) — NOT LoginScreen directly
      // AuthService is a StatelessWidget that acts as AuthGate via StreamBuilder
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthService()),
      );
    } else {
      // First time user → show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.15),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.cyan,
                  size: 40,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'NEVARK',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Decision Intelligence Platform',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}