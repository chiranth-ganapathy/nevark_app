import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  final _slides = [
    {
      'icon': Icons.analytics_outlined,
      'color': AppColors.cyan,
      'title': 'AI-Powered Signals',
      'body':
          'Get clear Buy / Sell / Hold signals for every stock. No charts to decode — just actionable intelligence.',
    },
    {
      'icon': Icons.pie_chart_outline,
      'color': AppColors.purple,
      'title': 'Sector Intelligence',
      'body':
          'Know which sectors are Bullish, Bearish, or Neutral before picking a stock. Invest with context.',
    },
    {
      'icon': Icons.shield_outlined,
      'color': AppColors.green,
      'title': 'Risk-Aware Decisions',
      'body':
          'Every signal comes with a risk rating and plain-English explanation. Built for retail investors.',
    },
  ];

  Future<void> _finish() async {
    // Mark onboarding as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;

    // ✓ FIX: Go to AuthService (AuthGate) — NOT LoginScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthService()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Space Mono',
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _Slide(data: _slides[i]),
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.cyan
                              : AppColors.textMuted.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_page == _slides.length - 1) {
                          _finish();
                        } else {
                          _ctrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _page == _slides.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final Map data;
  const _Slide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: (data['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (data['color'] as Color).withOpacity(0.3),
              ),
            ),
            child: Icon(
              data['icon'] as IconData,
              color: data['color'] as Color,
              size: 44,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            data['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Syne',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['body'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}