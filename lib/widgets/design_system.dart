import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glass card matching Pixel's design: rgba(255,255,255,0.04) bg, blur 30,
/// border rgba(255,255,255,0.08), radius 20-24px.
class HBotCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const HBotCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? HBotColors.glassBorder,
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? HBotColors.cardLight,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? HBotColors.borderLight,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Gradient button matching Pixel's design: 135deg primary→cyan, 16px radius, bold shadow.
class HBotGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double height;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final bool fullWidth;

  const HBotGradientButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.height = 52,
    this.enabled = true,
    this.padding,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: height,
        width: fullWidth ? double.infinity : null,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment(-0.5, -0.5),
                  end: Alignment(0.5, 0.5),
                  colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                )
              : null,
          color: enabled ? null : HBotColors.primaryDisabled,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x4D0883FD),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 15,
            fontWeight: FontWeight.w700,
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

/// Glass surface icon button (back, notifications, etc.) matching Pixel's design.
class HBotIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Widget? badge;

  const HBotIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HBotColors.glassBorder, width: 1),
            ),
            child: Icon(icon, size: 20, color: HBotColors.textMuted),
          ),
          if (badge != null)
            Positioned(top: 6, right: 6, child: badge!),
        ],
      ),
    );
  }
}

/// Notification dot badge
class HBotNotifDot extends StatelessWidget {
  final double size;
  const HBotNotifDot({super.key, this.size = 7});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: HBotColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Glass-style section label (overline)
class HBotSectionLabel extends StatelessWidget {
  final String text;
  const HBotSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Readex Pro',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: HBotColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Outline button matching Pixel's design for secondary actions (SSO, etc.)
class HBotOutlineButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;

  const HBotOutlineButton({
    super.key,
    required this.child,
    this.onTap,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HBotColors.glassBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Custom toggle switch matching Pixel's design.
class HBotToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  const HBotToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 44,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final knobSize = height - 4;
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  begin: Alignment(-0.5, -0.5),
                  end: Alignment(0.5, 0.5),
                  colors: [Color(0xFF0883FD), Color(0xFF2FB8EC)],
                )
              : null,
          color: value ? null : const Color(0x4D8A8F9E),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knobSize,
            height: knobSize,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark gradient background scaffold matching Pixel's design.
class HBotDarkScaffold extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const HBotDarkScaffold({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.title,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF010510), Color(0xFF0A1628)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (showBackButton || title != null || actions != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    if (showBackButton)
                      HBotIconButton(
                        icon: Icons.chevron_left,
                        onTap: onBack ?? () => Navigator.of(context).pop(),
                      ),
                    if (showBackButton) const SizedBox(width: 12),
                    if (title != null)
                      Text(
                        title!,
                        style: const TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    const Spacer(),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Hero gradient card (dashboard, device control top banner).
class HBotHeroCard extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const HBotHeroCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.borderRadius = 24,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        const [Color(0xFF1070AD), Color(0xFF0883FD), Color(0xFF2FB8EC)];
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.5),
          end: Alignment(0.5, 0.5),
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          // Decorative glow
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity( 0.12),
                    Colors.white.withOpacity( 0.0),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Settings tile row matching Pixel's settings design.
class HBotSettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;

  const HBotSettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.label,
    this.description,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0x140883FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor ?? HBotColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Readex Pro',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 11,
                        color: HBotColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, size: 16, color: HBotColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Pill tab (room tabs, filter chips) matching Pixel's scrollable pills.
class HBotPillTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const HBotPillTab({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment(-0.7, -0.7),
                  end: Alignment(0.7, 0.7),
                  colors: [Color(0xFF0883FD), Color(0xFF2FB8EC)],
                )
              : null,
          color: isActive ? null : HBotColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(color: const Color(0x14FFFFFF), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Readex Pro',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : HBotColors.textMuted,
          ),
        ),
      ),
    );
  }
}
