import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Settings Tile per design spec (03-COMPONENT-LIBRARY.md Section 2.3)
/// 56px height, icon + label + chevron
/// Grouped in card wrapper with 16px radius and 1px border
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? titleColor;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showDivider = true,
    this.titleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(
              horizontal: HBotSpacing.space4,
            ),
            child: Row(
              children: [
                // Icon
                Icon(
                  icon,
                  color: titleColor ?? HBotColors.iconDefault,
                  size: 24,
                ),
                const SizedBox(width: HBotSpacing.space3),
                // Label
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: titleColor ?? HBotColors.textPrimaryLight,
                    ),
                  ),
                ),
                // Value/trailing
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: HBotSpacing.space2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                  ),
                trailing ??
                    const Icon(
                      Icons.chevron_right,
                      color: HBotColors.neutral400,
                      size: 16,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(
              height: 1,
              color: HBotColors.neutral100,
            ),
          ),
      ],
    );
  }
}

/// Group wrapper for settings tiles
/// Per design spec: 16px radius, 1px border, white bg, 24px margin between groups
class SettingsTileGroup extends StatelessWidget {
  final List<Widget> children;
  final String? title;

  const SettingsTileGroup({
    super.key,
    required this.children,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: HBotSpacing.space1,
              bottom: HBotSpacing.space2,
            ),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: HBotColors.textTertiaryLight,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: HBotColors.cardLight,
            borderRadius: HBotRadius.largeRadius,
            border: Border.all(
              color: HBotColors.borderLight,
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: HBotSpacing.space6),
      ],
    );
  }
}
