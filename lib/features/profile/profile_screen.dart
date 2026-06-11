// lib/features/profile/profile_screen.dart
//
// Enhanced NeVark Profile Screen.
// Preserves existing nav tiles (Alerts, Macro, FII, Screener) + Sign Out behaviour.
// Adds: Header, Insights, Settings, Quick Actions, Security, About page.

// dart:ui removed — all used elements provided by flutter/material.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_service.dart';
import '../../core/config/display_mode.dart';
import '../../services/alerts/alert_store.dart';
import '../../services/market_store.dart';
import '../alert/alert_screen.dart';
import '../auth/auth_service.dart';
import '../fii/fii_screen.dart';
import '../screener/screener_screen.dart';
import 'about_screen.dart';
import 'legal_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ProfileScreen
// ═══════════════════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  bool _marketAlerts = true;
  bool _predictionAlerts = true;
  bool _professionalMode = false;
  String _version = '1.0.0';
  int _watchlistCount = 0;
  int _trackedStocks = 0;
  int _predictionsGenerated = 0;
  String _memberSince = '';
  String _displayName = 'Investor';
  String _email = '';

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  StreamSubscription<MarketSnapshot>? _marketSub;

  VoidCallback? _alertStoreListener;

  @override
  void initState() {
    super.initState();
    _alertStoreListener = () {
      if (mounted) setState(() {});
    };
    AlertStore.instance.addListener(_alertStoreListener!);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadPrefs();
    _marketSub = MarketStore.instance.stream.listen((_) {
      if (!mounted) return;
      setState(() {
        _predictionsGenerated = MarketStore.instance.predictions.length;
        if (_predictionsGenerated > 0) {
          SharedPreferences.getInstance().then((p) {
            p.setInt('predictions_count', _predictionsGenerated);
          });
        }
      });
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    final watchlist = prefs.getStringList('watchlist') ?? [];
    final storePredictions = MarketStore.instance.predictions.length;

    if (!mounted) return;
    setState(() {
      _version = info.version;
      _watchlistCount = watchlist.length;
      _trackedStocks =
          kNseTokens.keys.where((k) => !kPrimaryIndexKeys.contains(k)).length;
      _marketAlerts = prefs.getBool('pref_market_alerts') ?? true;
      _predictionAlerts = prefs.getBool('pref_prediction_alerts') ?? true;
      _professionalMode = DisplayMode.isProfessional.value;
      _predictionsGenerated = storePredictions > 0
          ? storePredictions
          : (prefs.getInt('predictions_count') ?? 0);

      _displayName = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : (prefs.getString('display_name') ?? 'Investor');
      _email = user?.email ?? prefs.getString('user_email') ?? '';

      final ts = prefs.getInt('member_since_ms');
      if (ts != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        _memberSince = '${_monthName(dt.month)} ${dt.year}';
      } else if (user?.metadata.creationTime != null) {
        final dt = user!.metadata.creationTime!;
        _memberSince = '${_monthName(dt.month)} ${dt.year}';
      } else {
        _memberSince = '—';
      }
    });
  }

  Future<void> _saveAlertPref(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  @override
  void dispose() {
    if (_alertStoreListener != null) {
      AlertStore.instance.removeListener(_alertStoreListener!);
    }
    _marketSub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: AppColors.surface,
          onRefresh: _loadPrefs,
          child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── Profile Header ──────────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 20),

            // ── Account Insights ────────────────────────────────────
            _SectionLabel('Account Insights', AppColors.cyan),
            const SizedBox(height: 10),
            _buildInsightsCard(),
            const SizedBox(height: 20),

            // ── App Navigation (preserved) ──────────────────────────
            _SectionLabel('Tools', AppColors.purple),
            const SizedBox(height: 4),
            _buildNavTiles(context),
            const SizedBox(height: 20),

            // ── Settings ─────────────────────────────────────────────
            _SectionLabel('Settings', AppColors.amber),
            const SizedBox(height: 4),
            _buildSettingsCard(),
            const SizedBox(height: 20),

            // ── Quick Actions ─────────────────────────────────────────
            _SectionLabel('More', AppColors.green),
            const SizedBox(height: 4),
            _buildQuickActions(context),
            const SizedBox(height: 20),

            // ── Security ─────────────────────────────────────────────
            _SectionLabel('Security', AppColors.red),
            const SizedBox(height: 4),
            _buildSecuritySection(context),
            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  // ── Profile Header ───────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
          AppColors.cyan.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.cyan.withValues(alpha: 0.3),
              AppColors.cyan.withValues(alpha: 0.05),
            ]),
            border: Border.all(
                color: AppColors.cyan.withValues(alpha: 0.5), width: 2),
          ),
            child: Icon(Icons.person_rounded,
              color: AppColors.cyan, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email.isNotEmpty ? _email : 'Not signed in',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 10, color: AppColors.cyan.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Member since $_memberSince',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: AppColors.cyan.withValues(alpha: 0.8),
                    ),
                  ),
                ]),
              ]),
        ),
        // Verified badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: Text(
            'PRO',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Insights card ────────────────────────────────────────────────────────

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        Row(children: [
          _InsightTile(
            label: 'Watchlist',
            value: '$_watchlistCount',
            icon: Icons.bookmark_rounded,
            color: AppColors.cyan,
          ),
          _InsightTile(
            label: 'Tracked',
            value: '$_trackedStocks',
            icon: Icons.show_chart_rounded,
            color: AppColors.green,
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _InsightTile(
            label: 'Predictions',
            value: '$_predictionsGenerated',
            icon: Icons.psychology_rounded,
            color: AppColors.purple,
          ),
          _InsightTile(
            label: 'App Version',
            value: 'v$_version',
            icon: Icons.info_rounded,
            color: AppColors.amber,
          ),
        ]),
      ]),
    );
  }

  // ── Nav tiles (preserved) ─────────────────────────────────────────────────

  Widget _buildNavTiles(BuildContext context) {
    return _TileGroup(tiles: [
      _TileData(
        'Alerts',
        Icons.notifications_outlined,
        AppColors.amber,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => AlertsScreen())),
        badge: AlertStore.instance.unreadCount,
      ),
      _TileData(
        'FII / DII Activity',
        Icons.account_balance_outlined,
        AppColors.green,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => FiiDiiScreen())),
      ),
      _TileData(
        'Stock Screener',
        Icons.filter_list,
        AppColors.purple,
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ScreenerScreen())),
      ),
    ]);
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: [
        _ToggleTile(
          icon: Icons.notifications_active_rounded,
          iconColor: AppColors.amber,
          title: 'Market Alerts',
          subtitle: 'NSE open/close + index moves',
          value: _marketAlerts,
          onChanged: (v) {
            setState(() => _marketAlerts = v);
            _saveAlertPref('pref_market_alerts', v);
          },
        ),
        Divider(
            color: AppColors.cardBorder, height: 1, indent: 54),
        _ToggleTile(
          icon: Icons.psychology_rounded,
          iconColor: AppColors.purple,
          title: 'Prediction Alerts',
          subtitle: 'BUY / SELL signal notifications',
          value: _predictionAlerts,
          onChanged: (v) {
            setState(() => _predictionAlerts = v);
            _saveAlertPref('pref_prediction_alerts', v);
          },
        ),
        Divider(
            color: AppColors.cardBorder, height: 1, indent: 54),
        _ToggleTile(
          icon: Icons.analytics_outlined,
          iconColor: AppColors.cyan,
          title: 'Professional Mode',
          subtitle: 'Show RSI, MACD, EMA and full technicals',
          value: _professionalMode,
          onChanged: (v) async {
            setState(() => _professionalMode = v);
            await DisplayMode.setProfessional(v);
          },
        ),
        Divider(
            color: AppColors.cardBorder, height: 1, indent: 54),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: DisplayMode.themeMode,
          builder: (context, mode, _) => ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.dark_mode_rounded,
              color: AppColors.cyan, size: 18),
          ),
            title: Text('Theme',
              style: TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
          subtitle: Text('Dark / Light / System',
              style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: AppColors.textMuted)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Text(mode == ThemeMode.dark
                ? 'DARK'
                : mode == ThemeMode.light
                    ? 'LIGHT'
                    : 'SYSTEM',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9,
                  color: AppColors.cyan,
                )),
          ),
          onTap: () => _showThemeOptions(context),
        ),
        ),
      ]),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return _TileGroup(tiles: [
      _TileData(
        'About NeVark',
        Icons.info_outline_rounded,
        AppColors.cyan,
        () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutScreen())),
      ),
      _TileData(
        'Privacy Policy',
        Icons.privacy_tip_outlined,
        AppColors.purple,
        () => openPrivacyPolicy(context),
      ),
      _TileData(
        'Terms & Conditions',
        Icons.description_outlined,
        AppColors.amber,
        () => openTerms(context),
      ),
      _TileData(
        'Contact Support',
        Icons.support_agent_rounded,
        AppColors.green,
        () => _launchWeb('mailto:support@nevark.in'),
      ),
      _TileData(
        'Share App',
        Icons.share_rounded,
        AppColors.cyan,
        () async {
          HapticFeedback.lightImpact();
          final pkg = await PackageInfo.fromPlatform();
          final text = 'Check out NeVark (${pkg.version}) — AI stock research app.\nhttps://nevark.in';
          await Share.share(text);
        },
      ),
      _TileData(
        'Rate App',
        Icons.star_rate_rounded,
        AppColors.amber,
        () => _launchWeb('https://play.google.com/store'),
      ),
    ]);
  }

  // ── Security ─────────────────────────────────────────────────────────────

  Widget _buildSecuritySection(BuildContext context) {
    return _TileGroup(tiles: [
      _TileData(
        'Reset Password',
        Icons.lock_reset_rounded,
        AppColors.amber,
        () => _showResetPasswordDialog(context),
      ),
      _TileData(
        'Sign Out',
        Icons.logout_rounded,
        AppColors.red,
        () => _confirmLogout(context),
      ),
    ]);
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showResetPasswordDialog(BuildContext context) {
    final email = _email;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email on account. Sign in with email/password first.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Reset Password',
          style: TextStyle(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
        content: Text(
          'Send a password reset link to $email?',
          style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Space Mono',
                    color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final err = await AuthService.forgotPassword(email: email);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  err ?? 'Reset link sent! Check your email.',
                  style: const TextStyle(fontFamily: 'Space Mono'),
                ),
                backgroundColor: err != null
                    ? AppColors.red.withValues(alpha: 0.9)
                    : AppColors.green.withValues(alpha: 0.8),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Text('Send Link',
                style: TextStyle(
                    fontFamily: 'Space Mono',
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to sign out of NeVark?',
          style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(
                    fontFamily: 'Space Mono',
                    color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.signOut();
            },
            child: Text('Sign Out',
                style: TextStyle(
                    fontFamily: 'Space Mono',
                    color: AppColors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showThemeOptions(BuildContext context) {
    final current = DisplayMode.themeMode.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text('Use system theme'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) DisplayMode.setThemeMode(v);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                DisplayMode.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Light'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) DisplayMode.setThemeMode(v);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                DisplayMode.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Dark'),
              leading: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) DisplayMode.setThemeMode(v);
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                DisplayMode.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ]),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  static Future<void> _launchWeb(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(children: [
        Container(
            width: 3, height: 12, color: color,
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
      ]),
    );
  }
}

// ── Insight tile ─────────────────────────────────────────────────────────────

class _InsightTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _InsightTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9,
                  color: AppColors.textMuted,
                )),
          ]),
        ]),
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
        title: Text(title,
          style:
            TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.textMuted)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: iconColor,
        activeTrackColor: iconColor.withValues(alpha: 0.25),
        inactiveThumbColor: AppColors.textMuted,
        inactiveTrackColor: AppColors.surface2,
      ),
    );
  }
}

// ── Tile group (card container) ───────────────────────────────────────────────

class _TileData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const _TileData(this.title, this.icon, this.color, this.onTap,
      {this.badge = 0});
}

class _TileGroup extends StatelessWidget {
  final List<_TileData> tiles;
  const _TileGroup({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          return Column(children: [
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(t.icon, color: t.color, size: 18),
              ),
              title: Text(t.title,
                  style: TextStyle(
                    color: t.title == 'Sign Out'
                        ? AppColors.red
                        : AppColors.textPrimary,
                    fontSize: 14,
                  )),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.badge > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.badge}',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 18),
                ],
              ),
              onTap: t.onTap,
            ),
            if (i < tiles.length - 1)
              Divider(
                  color: AppColors.cardBorder,
                  height: 1,
                  indent: 54),
          ]);
        }).toList(),
      ),
    );
  }
}
