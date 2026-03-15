import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ProfileCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? HBotColors.cardLight : HBotColors.cardLight;
    final textPrimary = isDark
        ? HBotColors.textPrimaryLight
        : HBotColors.textPrimaryLight;
    final textSecondary = isDark
        ? HBotColors.textSecondaryLight
        : HBotColors.textSecondaryLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(HBotRadius.medium),
          border: Border.all(
            color: isDark
                ? color.withOpacity(0.3)
                : HBotColors.borderLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(HBotRadius.small),
              ),
              child: Icon(icon, color: color, size: 24),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Value
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // Title
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
