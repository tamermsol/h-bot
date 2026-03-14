import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Device Card per design spec (03-COMPONENT-LIBRARY.md Section 2.1)
/// White bg, 16px radius, 1px border #E8ECF1, min height 140px, 16px padding
/// ON state: 3px left blue accent border, icon = $iconActive
/// OFF state: default border, icon = $iconDefault
/// Pressed: bg → #F0F2F5, scale 0.98
/// Unreachable: opacity 0.5, red dot 6px top-right
/// Custom gradient toggle (gradient track when ON, flat #D1D7E0 when OFF)
class DeviceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool? isOnline;
  final bool isOn;
  final String? value;
  final String? roomName;
  final Function(bool) onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? deviceColor;
  final bool isLoading;

  const DeviceCard({
    super.key,
    required this.title,
    required this.icon,
    this.isOnline,
    required this.isOn,
    required this.onToggle,
    this.value,
    this.roomName,
    this.onTap,
    this.onLongPress,
    this.deviceColor,
    this.isLoading = false,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isPressed = false;

  Color get _activeColor => widget.deviceColor ?? HBotColors.primary;

  @override
  Widget build(BuildContext context) {
    final online = widget.isOnline ?? widget.isOn;
    final bool unreachable = widget.isOnline == false && !widget.isOn;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: HBotDurations.fast,
        curve: HBotCurves.standard,
        child: AnimatedContainer(
          duration: HBotDurations.fast,
          curve: HBotCurves.standard,
          constraints: const BoxConstraints(minHeight: 140),
          decoration: BoxDecoration(
            color: _isPressed
                ? HBotColors.surfaceCardHover
                : HBotColors.cardLight,
            borderRadius: HBotRadius.largeRadius,
            border: Border.all(
              color: HBotColors.borderLight,
              width: 1,
            ),
          ),
          child: Opacity(
            opacity: unreachable ? 0.5 : 1.0,
            child: ClipRRect(
              borderRadius: HBotRadius.largeRadius,
              child: Stack(
                children: [
                  // Left blue accent border for ON state (3px)
                  if (widget.isOn)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        color: HBotColors.primary,
                      ),
                    ),

                  // Unreachable red dot indicator (6px top-right)
                  if (unreachable)
                    Positioned(
                      top: HBotSpacing.space2,
                      right: HBotSpacing.space2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: HBotColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                  // Card content with 16px padding
                  Padding(
                    padding: const EdgeInsets.all(HBotSpacing.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: icon + name row
                        Row(
                          children: [
                            // Device type icon (32px per spec)
                            Icon(
                              widget.icon,
                              color: widget.isOn
                                  ? HBotColors.iconActive
                                  : HBotColors.iconDefault,
                              size: 32,
                            ),
                          ],
                        ),

                        const SizedBox(height: HBotSpacing.space2),

                        // Device name ($titleMedium 16/600, max 2 lines)
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HBotColors.textPrimaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Room label ($bodySmall 12/400, textSecondary)
                        if (widget.roomName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.roomName!,
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

                        const SizedBox(height: HBotSpacing.space2),

                        // State text ($bodyMedium 14/400)
                        if (widget.isLoading)
                          Container(
                            width: 40,
                            height: 12,
                            decoration: BoxDecoration(
                              color: HBotColors.neutral100,
                              borderRadius: HBotRadius.smallRadius,
                            ),
                          )
                        else
                          Text(
                            widget.value ?? (widget.isOn ? 'ON' : 'OFF'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: widget.isOn
                                  ? HBotColors.primary
                                  : HBotColors.textSecondaryLight,
                            ),
                          ),

                        const SizedBox(height: HBotSpacing.space3),

                        // Toggle at bottom — custom gradient toggle
                        Align(
                          alignment: Alignment.centerRight,
                          child: _GradientToggle(
                            value: widget.isOn,
                            onChanged: unreachable ? null : widget.onToggle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom gradient toggle switch per design spec (Component Library §5.1)
/// Track: 52x32px, gradient when ON (#0883FD→#8CD1FB), flat #D1D7E0 when OFF
/// Thumb: 28x28px white circle with small shadow
class _GradientToggle extends StatelessWidget {
  final bool value;
  final Function(bool)? onChanged;

  const _GradientToggle({
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: HBotDurations.medium,
        curve: HBotCurves.standard,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          gradient: value ? HBotColors.primaryGradient : null,
          color: value ? null : HBotColors.toggleTrackOff,
          borderRadius: BorderRadius.circular(HBotRadius.full),
        ),
        child: AnimatedAlign(
          duration: HBotDurations.medium,
          curve: HBotCurves.standard,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: HBotColors.toggleThumb,
              shape: BoxShape.circle,
              boxShadow: HBotShadows.small,
            ),
          ),
        ),
      ),
    );
  }
}
