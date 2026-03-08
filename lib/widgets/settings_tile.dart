import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? AppTheme.surfaceColor
        : AppTheme.lightSurfaceColor;
    final textPrimary = isDark
        ? AppTheme.textPrimary
        : AppTheme.lightTextPrimary;
    final textSecondary = isDark
        ? AppTheme.textSecondary
        : AppTheme.lightTextSecondary;
    final textHint = isDark ? AppTheme.textHint : AppTheme.lightTextHint;
    final dividerColor = isDark
        ? AppTheme.textHint
        : AppTheme.lightDividerColor;

    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Icon(icon, color: titleColor ?? textPrimary, size: 20),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleColor ?? textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textSecondary),
          ),
          trailing:
              trailing ?? Icon(Icons.chevron_right, color: textHint, size: 20),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMedium,
            vertical: 4,
          ),
        ),
        if (showDivider)
          Divider(
            color: dividerColor.withValues(alpha: 0.5),
            height: 1,
            indent: AppTheme.paddingMedium,
            endIndent: AppTheme.paddingMedium,
          ),
      ],
    );
  }
}
