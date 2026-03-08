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
    final Color sceneColor = scene['color'] ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isActive
                ? sceneColor.withOpacity(0.5)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? sceneColor.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? sceneColor.withOpacity(0.2)
                        : AppTheme.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    scene['icon'],
                    color: isActive ? sceneColor : AppTheme.textHint,
                    size: 20,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isActive,
                    onChanged: onToggle,
                    inactiveTrackColor: AppTheme.textHint.withOpacity(0.3),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Scene name
            Text(
              scene['name'],
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Scene description
            Text(
              scene['description'],
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? AppTheme.textSecondary : AppTheme.textHint,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Time/trigger info
            Row(
              children: [
                Icon(
                  _getTimeIcon(scene['time']),
                  size: 10,
                  color: isActive ? sceneColor : AppTheme.textHint,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    scene['time'],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive ? sceneColor : AppTheme.textHint,
                      fontSize: 10,
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
