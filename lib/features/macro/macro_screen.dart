import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MacroScreen extends StatelessWidget {
  const MacroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Macro Indicators')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.public, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Macro indicators',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RBI repo rate, CPI, GDP and global macro feeds will be added in a future release. '
                'Use the Dashboard and Sector screens for live NSE data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
