import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_screen.dart';
import '../news/repositories/news_repository.dart';
import '../../services/intelligence/intelligence_engine.dart';
import '../watchlist/watchlist_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../news/news_screen.dart';
import '../profile/profile_screen.dart';

import '../../core/theme/app_theme.dart';
import '../../services/alerts/alert_store.dart';
import '../alert/alert_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _idx = 0;
  int _alertHistoryLen = 0;
  VoidCallback? _alertListener;

  @override
  void initState() {
    super.initState();
    _alertHistoryLen = AlertStore.instance.history.length;
    _alertListener = () {
      final store = AlertStore.instance;
      if (store.history.length <= _alertHistoryLen) {
        _alertHistoryLen = store.history.length;
        return;
      }
      final latest = store.history.first;
      _alertHistoryLen = store.history.length;
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            latest.title,
            style: const TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AlertsScreen()),
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    };
    AlertStore.instance.addListener(_alertListener!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsRepositoryProvider);
      IntelligenceEngine.bootstrap();
    });
  }

  @override
  void dispose() {
    if (_alertListener != null) {
      AlertStore.instance.removeListener(_alertListener!);
    }
    super.dispose();
  }

  final List<Widget> _pages = const [
    DashboardScreen(),
    WatchlistScreen(),
    ChatbotScreen(),
    NewsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _idx,
        children: _pages,
      ),
      bottomNavigationBar: _NeVarkNavBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ── Custom bottom nav bar ────────────────────────────────
class _NeVarkNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _NeVarkNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded, label: 'Market'),
    _NavItem(icon: Icons.bookmark_border_rounded,
        activeIcon: Icons.bookmark_rounded, label: 'Watchlist'),
    _NavItem(icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy_rounded, label: 'AI'),
    _NavItem(icon: Icons.newspaper_outlined,
        activeIcon: Icons.newspaper_rounded, label: 'News'),
    _NavItem(icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.cyan.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            selected ? item.activeIcon : item.icon,
                            color: selected
                                ? AppColors.cyan
                                : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 9,
                            color: selected
                                ? AppColors.cyan
                                : AppColors.textMuted,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}
