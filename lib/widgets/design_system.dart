import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean card matching v0 design: #F5F7FA bg, #E5E7EB border, 16px radius.
/// No glassmorphism, no backdrop blur, no ambient backgrounds.
class HBotCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const HBotCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = HBotTheme.isDark(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark ? HBotColors.cardDark : HBotColors.cardLight),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (isDark ? HBotColors.borderDark : HBotColors.borderLight),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Gradient button matching v0 design: primary gradient bg, 12px radius, 48px height.
/// Shadow: 0 8px 24px rgba(8,131,253,0.38) per v0 FAB spec.
class HBotGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double height;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  const HBotGradientButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 12,
    this.height = 48,
    this.enabled = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: height,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: enabled ? HBotColors.primaryGradient : null,
          color: enabled ? null : HBotColors.primaryDisabled,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: enabled ? HBotColors.fabShadow : null,
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white, size: 20),
            child: child,
          ),
        ),
      ),
    );
  }
}
