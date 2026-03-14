import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Glassmorphism card widget per BRAND-DNA.md
/// Uses BackdropFilter with 30-45px blur on frosted glass surfaces.
/// Dark mode: semi-transparent dark bg with blur.
/// Light mode: semi-transparent white bg with blur.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderWidth;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 30,
    this.borderRadius = 16,
    this.padding,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = HBotTheme.isDark(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A202B).withOpacity(0.7)
                : Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ??
                  (isDark
                      ? const Color(0xFF181B1F).withOpacity(0.6)
                      : const Color(0xFFE8ECF1).withOpacity(0.6)),
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ambient background gradient per BRAND-DNA.md Section 2
/// Dark mode: RadialGradient with rgba(9,73,114,0.2-0.3) center to rgba(1,5,16,0.2-0.3) edge
/// Light mode: Subtle blue-tinted gradient instead of flat #F8F9FB
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = HBotTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [
                  Color(0x4D094972), // rgba(9,73,114,0.3)
                  Color(0x4D010510), // rgba(1,5,16,0.3)
                ],
              )
            : const RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.5,
                colors: [
                  Color(0x0A0883FD), // rgba(8,131,253,0.04)
                  Color(0x00F8F9FB), // rgba(248,249,251,0) transparent
                ],
              ),
        color: isDark ? HBotColors.backgroundDark : HBotColors.backgroundLight,
      ),
      child: child,
    );
  }
}

/// Decorative gradient divider per BRAND-DNA.md
/// Uses #1070AD to #CBD9DE at 225 degrees
class GradientDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;

  const GradientDivider({
    super.key,
    this.height = 1,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1070AD), Color(0xFFCBD9DE)],
        ),
      ),
    );
  }
}

/// Inset shadow container for recessed elements per BRAND-DNA.md
/// rgba(0,0,0,0.12) 0 0 5.78px inset equivalent
class InsetShadowContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const InsetShadowContainer({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = HBotTheme.isDark(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ??
            (isDark ? const Color(0xFF141A26) : const Color(0xFFF0F2F5)),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          // Simulate inset shadow using inner shadow technique
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.black.withOpacity(0.2)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Animated gradient fill for device toggle state changes per BRAND-DNA.md Section 6
/// Smooth transition when devices turn on/off
/// Glass-style bottom sheet wrapper for frosted glass effect on modal sheets
/// Wrap bottom sheet content with this for glassmorphism per BRAND-DNA.md
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final double blur;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.blur = 30,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = HBotTheme.isDark(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A202B).withOpacity(0.8)
                : Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE8ECF1).withOpacity(0.8),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Helper to show a glassmorphic bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBottomSheet(
        child: builder(context),
      ),
    );
  }
}

class AnimatedGradientContainer extends StatelessWidget {
  final bool isActive;
  final Widget child;
  final Duration duration;
  final double borderRadius;

  const AnimatedGradientContainer({
    super.key,
    required this.isActive,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isActive ? HBotColors.primaryGradient : null,
        color: isActive ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
