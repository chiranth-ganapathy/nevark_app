import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glass-style fintech card (visual only).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = accent?.withValues(alpha: 0.35) ?? AppColors.cardBorder;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface.withValues(alpha: 0.92),
                AppColors.surface2.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: [
              if (accent != null)
                BoxShadow(
                  color: accent!.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.cyan.withValues(alpha: 0.08),
        highlightColor: AppColors.cyan.withValues(alpha: 0.04),
        child: card,
      ),
    );
  }
}
