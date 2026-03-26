import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Settings item — 56px row inside a SettingsGroup
/// Design: 03-COMPONENT-LIBRARY.md §2.3
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: HBotSpacing.space4,
              vertical: HBotSpacing.space3,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: iconColor ?? titleColor ?? HBotColors.iconDefault,
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
                          fontFamily: 'DM Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: titleColor ?? context.hTextPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.hTextTertiary,
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
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.hTextSecondary,
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
                    color: HBotColors.neutral400,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 56),
            child: Container(height: 1, color: HBotColors.borderSubtle),
          ),
      ],
    );
  }
}

/// Grouped card wrapper for settings items
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
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: context.hTextSecondary,
              ),
            ),
          ),
        ],
        Container(
          margin: margin ??
              const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
          decoration: BoxDecoration(
            color: context.hCard,
            borderRadius: HBotRadius.largeRadius,
            border: Border.all(color: context.hBorder, width: 1),
          ),
          child: ClipRRect(
            borderRadius: HBotRadius.largeRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
