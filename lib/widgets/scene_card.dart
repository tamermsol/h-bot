import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scene Card — horizontal list item (72px height)
/// Design: 03-COMPONENT-LIBRARY.md §2.2
class SceneCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData? icon;
  final String? emoji;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  const SceneCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.icon,
    this.emoji,
    this.onTap,
    this.onPlay,
    this.onLongPress,
  });

  @override
  State<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<SceneCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: HBotDurations.fast,
        height: 72,
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: _isPressed ? HBotColors.cardHover : context.hCard,
          borderRadius: HBotRadius.largeRadius,
          border: Border.all(color: context.hBorder, width: 1),
        ),
        child: Row(
          children: [
            // Scene icon in tinted circle
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: HBotColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.emoji != null
                    ? Text(widget.emoji!, style: const TextStyle(fontSize: 20))
                    : Icon(
                        widget.icon ?? Icons.play_circle_outline,
                        color: HBotColors.primary,
                        size: 24,
                      ),
              ),
            ),

            const SizedBox(width: HBotSpacing.space3),

            // Name + subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.hTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.hTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: HBotSpacing.space3),

            // Play button
            if (widget.onPlay != null)
              GestureDetector(
                onTap: widget.onPlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: HBotColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
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
}
