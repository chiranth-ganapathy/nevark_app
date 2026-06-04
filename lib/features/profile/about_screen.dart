// lib/features/profile/about_screen.dart
//
// Modern About NeVark page — dark theme, glassmorphism, neon accents.

// dart:ui removed — all used elements provided by flutter/material.dart

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  String _version = '1.0.0';
  String _buildNumber = '1';
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('About NeVark'),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.cyan, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Hero logo card ──────────────────────────────────
                _GlassCard(
                  child: Column(children: [
                    // Logo hex
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.cyan.withValues(alpha: 0.25),
                          AppColors.purple.withValues(alpha: 0.1),
                          Colors.transparent,
                        ]),
                        border: Border.all(
                            color: AppColors.cyan.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Center(
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Ne',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'V',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.cyan,
                                ),
                              ),
                              TextSpan(
                                text: 'ark',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tagline
                    const Text(
                      'Decision Intelligence Platform',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'for Retail Investors',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 12,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Version chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        'Version $_version (Build $_buildNumber)',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Description card ────────────────────────────────
                _GlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardLabel('What is NeVark?', AppColors.cyan),
                        const SizedBox(height: 10),
                        const Text(
                          'NeVark is an AI-powered Decision Intelligence Platform built for Indian retail investors. '
                          'It combines real-time NSE market data, technical analysis, AI-driven predictions, '
                          'and live sentiment from market news — all in one place.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.7,
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: 16),

                // ── Company card ─────────────────────────────────────
                _GlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardLabel('Company', AppColors.purple),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.business_rounded,
                          label: 'Organisation',
                          value: 'Nevark Technologies LLP',
                        ),
                        const Divider(color: AppColors.cardBorder, height: 20),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          label: 'Market',
                          value: 'National Stock Exchange (NSE), India',
                        ),
                        const Divider(color: AppColors.cardBorder, height: 20),
                        _InfoRow(
                          icon: Icons.verified_rounded,
                          label: 'Data Source',
                          value: 'Angel One SmartAPI · Yahoo Finance',
                        ),
                      ]),
                ),
                const SizedBox(height: 16),

                // ── Features card ────────────────────────────────────
                _GlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardLabel('Features', AppColors.green),
                        const SizedBox(height: 12),
                        ..._features.map((f) => _FeatureRow(f.$1, f.$2)),
                      ]),
                ),
                const SizedBox(height: 16),

                // ── Disclaimer ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.amber, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'NeVark provides tools for market research only. '
                          'Nothing on this platform constitutes financial advice. '
                          'Invest at your own risk.',
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 10,
                            color: AppColors.amber.withValues(alpha: 0.8),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const _features = [
  (Icons.show_chart_rounded, 'Live NSE stock data via Angel One SmartAPI'),
  (Icons.psychology_rounded, 'AI-powered buy/sell predictions'),
  (Icons.newspaper_rounded, 'Real-time market news + sentiment analysis'),
  (Icons.pie_chart_rounded, 'Sector-wise analysis & FII/DII activity'),
  (Icons.star_rounded, 'Smart watchlist with alerts'),
  (Icons.chat_rounded, 'AI chatbot for market queries'),
];

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _CardLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 3, height: 14, color: color,
          margin: const EdgeInsets.only(right: 8)),
      Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.textMuted, size: 16),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            )),
      ]),
    ]);
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.green, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
