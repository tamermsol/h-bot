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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: HBotColors.cardLight,
          borderRadius: HBotRadius.largeRadius,
          border: Border.all(
            color: HBotColors.borderLight,
            width: 1,
          ),
          boxShadow: HBotShadows.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: HBotRadius.smallRadius,
              ),
              child: Icon(icon, color: color, size: 24),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Value
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: HBotColors.textPrimaryLight,
              ),
            ),

            const SizedBox(height: HBotSpacing.space1),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: HBotColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
