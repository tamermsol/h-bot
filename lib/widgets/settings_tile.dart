import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Settings Tile per design spec (03-COMPONENT-LIBRARY.md Section 2.3)
/// 56px height, 16px horizontal padding
/// Icon: 24px, iconDefault=#5A6577
/// Label: bodyLarge 16/400, textPrimary=#0A1628
/// Value: bodyMedium 14/400, textSecondary=#5A6577
/// Chevron: 16px, neutral400
/// Pressed bg = neutral100
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: HBotColors.neutral100,
            highlightColor: HBotColors.neutral100,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(
                horizontal: HBotSpacing.space4,
              ),
              child: Row(
                children: [
                  // Icon (24px, $iconDefault)
                  Icon(
                    icon,
                    color: titleColor ?? HBotColors.iconDefault,
                    size: 24,
                  ),
                  const SizedBox(width: HBotSpacing.space3),
                  // Label ($bodyLarge 16/400, $textPrimary)
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
                  // Value text ($bodyMedium 14/400, $textSecondary)
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
                  // Trailing widget or chevron (16px, neutral400)
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
        ),
        // Inner divider: 1px #F0F2F5, inset 56px from leading
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

/// Group wrapper for settings tiles per design spec
/// White bg, 1px border #E8ECF1, 16px radius
/// Inner dividers between tiles (1px #F0F2F5, inset from leading)
/// 24px margin bottom between groups
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
