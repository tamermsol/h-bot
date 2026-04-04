import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Settings item — row inside a SettingsGroup
/// Design: Pixel's approved dark glass — 15px padding, 36x36 icon bg, 14px label + 11px desc
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool showChevron;
  final Color? titleColor;
  final Color? iconColor;
  final Widget? trailing;
  /// Background color for the icon container; defaults to glass with icon color tint.
  final Color? iconBackgroundColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.showDivider = true,
    this.showChevron = true,
    this.titleColor,
    this.iconColor,
    this.trailing,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? titleColor ?? HBotColors.primary;
    final effectiveIconBg = iconBackgroundColor ??
        effectiveIconColor.withOpacity( 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: HBotColors.primary.withOpacity(0.06),
            highlightColor: HBotColors.primary.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              child: Row(
                children: [
                  // Icon with glass + colored background — 36x36
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: effectiveIconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 18,
                        color: effectiveIconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: HBotSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: titleColor ?? Colors.white,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: HBotColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: HBotSpacing.space2),
                    Text(
                      value!,
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: HBotColors.textMuted,
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: HBotSpacing.space2),
                    trailing!,
                  ] else if (showChevron) ...[
                    const SizedBox(width: HBotSpacing.space2),
                    const Icon(
                      Icons.chevron_right,
                      color: HBotColors.textMuted,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 64),
            child: Container(
              height: 0.5,
              color: const Color(0x0AFFFFFF), // rgba(255,255,255,0.04)
            ),
          ),
      ],
    );
  }
}

/// Grouped card wrapper for settings items — glass style
/// Design: 03-COMPONENT-LIBRARY.md §2.3 Group wrapper
class SettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const SettingsGroup({
    super.key,
    this.label,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: HBotSpacing.space5,
              bottom: HBotSpacing.space2,
              top: HBotSpacing.space6,
            ),
            child: Text(
              label!.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: HBotColors.textMuted,
              ),
            ),
          ),
        ],
        Container(
          margin: margin ??
              const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          decoration: BoxDecoration(
            color: HBotColors.glassBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HBotColors.glassBorder, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: HBotColors.glassBlur,
                sigmaY: HBotColors.glassBlur,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
