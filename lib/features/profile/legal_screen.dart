import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            kSebiDisclaimer,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.amber.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

const _privacyText = '''
NeVark respects your privacy. We collect only information required to operate the app:

• Firebase Authentication email and account identifiers
• Locally stored watchlist preferences on your device
• Anonymous usage required for market data and news APIs

We do not sell your personal data. Market data is provided by third-party APIs (Angel One, Yahoo Finance) subject to their terms.

Contact: support@nevark.in
''';

const _termsText = '''
By using NeVark you agree that:

• The app provides educational market information only
• AI signals and predictions are not financial advice
• You are responsible for your own investment decisions
• Live data may be delayed or unavailable during outages
• You must comply with applicable securities laws in India

NeVark is provided "as is" without warranty. We may update these terms from time to time.
''';

void openPrivacyPolicy(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LegalScreen(title: 'Privacy Policy', body: _privacyText),
    ),
  );
}

void openTerms(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LegalScreen(title: 'Terms & Conditions', body: _termsText),
    ),
  );
}
