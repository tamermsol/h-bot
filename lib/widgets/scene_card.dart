import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SceneCard extends StatelessWidget {
  final Map<String, dynamic> scene;
  final Function(bool) onToggle;
  final VoidCallback? onTap;

  const SceneCard({
    super.key,
    required this.scene,
    required this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = scene['isActive'] ?? false;
    final Color sceneColor = scene['color'] ?? HBotColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: isActive ? HBotColors.primarySurface : HBotColors.cardLight,
          borderRadius: HBotRadius.largeRadius,
          border: Border.all(
            color: isActive
                ? HBotColors.primary.withOpacity(0.2)
                : HBotColors.borderLight,
            width: 1,
          ),
          boxShadow: isActive ? HBotShadows.small : HBotShadows.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: gradient icon circle + toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Scene icon in gradient circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isActive ? HBotColors.primaryGradient : null,
                    color: isActive ? null : HBotColors.neutral100,
                    borderRadius: HBotRadius.smallRadius,
                  ),
                  child: Icon(
                    scene['icon'],
                    color: isActive ? Colors.white : HBotColors.neutral400,
                    size: 20,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: isActive,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Scene name
            Text(
              scene['name'],
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? HBotColors.textPrimaryLight : HBotColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Description
            Text(
              scene['description'],
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: HBotColors.textTertiaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: HBotSpacing.space2),

            // Time/trigger
            Row(
              children: [
                Icon(
                  _getTimeIcon(scene['time']),
                  size: 12,
                  color: isActive ? sceneColor : HBotColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    scene['time'],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isActive ? sceneColor : HBotColors.textTertiaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTimeIcon(String time) {
    if (time.toLowerCase().contains('manual')) {
      return Icons.touch_app;
    } else if (time.toLowerCase().contains('location')) {
      return Icons.location_on;
    } else {
      return Icons.schedule;
    }
  }
}
