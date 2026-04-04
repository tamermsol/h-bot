import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scene Card — gradient tile for 2x2 grid layout
/// Design: Scenes-C colored tile grid with radial glow
class SceneCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final IconData? icon;
  final String? emoji;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;
  final bool isExecuting;
  final bool isEnabled;

  const SceneCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.icon,
    this.emoji,
    this.gradient,
    this.onTap,
    this.onPlay,
    this.onLongPress,
    this.isExecuting = false,
    this.isEnabled = true,
  });

  @override
  State<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<SceneCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tileGradient = widget.gradient ?? HBotColors.sceneAwayGradient;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: HBotDurations.fast,
        child: Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.5,
          child: Container(
            constraints: const BoxConstraints(minHeight: 140),
            decoration: BoxDecoration(
              gradient: tileGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Decorative radial glow — single 100x100 overlay
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content — centered
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon or emoji or loading spinner
                      if (widget.isExecuting)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else if (widget.emoji != null)
                        Text(widget.emoji!, style: const TextStyle(fontSize: 32))
                      else
                        Icon(
                          widget.icon ?? Icons.play_circle_outline,
                          color: Colors.white,
                          size: 32,
                        ),

                      const SizedBox(height: HBotSpacing.space3),

                      // Name
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),

                      if (widget.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Status badge
                      if (widget.isEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Play button — top right
                if (widget.onPlay != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onPlay,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
