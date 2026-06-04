import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class FiiDiiScreen extends StatelessWidget {
  const FiiDiiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('FII / DII Activity')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'FII / DII flows',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Institutional flow data is not yet connected. '
                'This module will show monthly FII/DII activity when integrated.',
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
