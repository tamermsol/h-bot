import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scene Card per design spec (03-COMPONENT-LIBRARY.md Section 2.2)
/// 72px height, 16px padding, white bg, 1px border, 16px radius
/// Leading: 40x40 circle, #F0F7FF bg, emoji/icon 24px inside
/// Title: 16px/600, textPrimary
/// Subtitle: 12px/400, textSecondary (e.g., "5 devices")
/// Trailing: 40x40 circle, #F0F7FF bg, play icon 24px, #0883FD color
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
        constraints: const BoxConstraints(minHeight: 72),
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
            // Scene icon in 40px circle with $surfacePrimarySubtle bg
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: HBotColors.surfacePrimarySubtle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: scene['emoji'] != null
                  ? Text(
                      scene['emoji'],
                      style: const TextStyle(fontSize: 24),
                    )
                  : Icon(
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
                  // Title: $titleMedium 16/600, textPrimary
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
                      scene['time'] != null ||
                      scene['deviceCount'] != null) ...[
                    const SizedBox(height: 2),
                    // Subtitle: $bodySmall 12/400, textSecondary
                    Text(
                      scene['description'] ??
                          scene['time'] ??
                          (scene['deviceCount'] != null
                              ? '${scene['deviceCount']} devices'
                              : ''),
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

            // Play button: 40x40 circle, $surfacePrimarySubtle bg, play icon
            GestureDetector(
              onTap: onPlay ?? () => onToggle(!isActive),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: HBotColors.surfacePrimarySubtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
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
