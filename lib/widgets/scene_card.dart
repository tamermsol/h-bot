import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scene Card per design spec (03-COMPONENT-LIBRARY.md Section 2.2)
/// 72px height, horizontal layout
/// Scene icon in 40px circle ($surfacePrimarySubtle bg)
/// Scene name ($titleMedium 16/600) + subtitle ($bodySmall 12/400)
/// Play button (40x40 circle) on the right
class SceneCard extends StatelessWidget {
  final Map<String, dynamic> scene;
  final Function(bool) onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const SceneCard({
    super.key,
    required this.scene,
    required this.onToggle,
    this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = scene['isActive'] ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: HBotColors.cardLight,
          borderRadius: HBotRadius.largeRadius,
          border: Border.all(
            color: HBotColors.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Scene icon in 40px circle with blue-tinted bg
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: HBotColors.surfacePrimarySubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                scene['icon'] ?? Icons.auto_awesome,
                color: HBotColors.primary,
                size: 24,
              ),
            ),

            const SizedBox(width: HBotSpacing.space3),

            // Scene name + subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene['name'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HBotColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (scene['description'] != null ||
                      scene['time'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      scene['description'] ?? scene['time'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: HBotColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: HBotSpacing.space3),

            // Play button (40x40 circle)
            GestureDetector(
              onTap: onPlay ?? () => onToggle(!isActive),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: HBotColors.surfacePrimarySubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.pause : Icons.play_arrow,
                  color: HBotColors.primary,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep legacy helper for backwards compatibility
  static IconData getTimeIcon(String time) {
    if (time.toLowerCase().contains('manual')) {
      return Icons.touch_app;
    } else if (time.toLowerCase().contains('location')) {
      return Icons.location_on;
    } else {
      return Icons.schedule;
    }
  }
}
