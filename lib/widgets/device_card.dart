import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Device Card — 2-column grid item on Home Dashboard
/// Design: 03-COMPONENT-LIBRARY.md §2.1
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
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isPressed = false;

  Color get _activeColor => widget.deviceColor ?? HBotColors.primary;
  bool get _unreachable => widget.isOnline == false;

  @override
  Widget build(BuildContext context) {
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
          duration: HBotDurations.medium,
          curve: HBotCurves.standard,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(HBotSpacing.space4),
          decoration: BoxDecoration(
            color: _isPressed ? HBotColors.cardHover : HBotColors.cardLight,
            borderRadius: HBotRadius.largeRadius,
            border: Border(
              left: BorderSide(
                color: widget.isOn ? _activeColor : HBotColors.borderLight,
                width: widget.isOn ? 3 : 1,
              ),
              top: const BorderSide(color: HBotColors.borderLight, width: 1),
              right: const BorderSide(color: HBotColors.borderLight, width: 1),
              bottom: const BorderSide(color: HBotColors.borderLight, width: 1),
            ),
          ),
          child: Opacity(
            opacity: _unreachable ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Device icon with optional unreachable dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.isOn ? _activeColor : HBotColors.iconDefault,
                      size: 32,
                    ),
                    if (_unreachable)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: hbotStatusDot(color: HBotColors.error, size: 8),
                      ),
                  ],
                ),

                const SizedBox(height: HBotSpacing.space3),

                // Device name — centered
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: HBotColors.textPrimaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                if (widget.value != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.value!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isOn
                          ? _activeColor
                          : HBotColors.textSecondaryLight,
                    ),
                  ),
                ],

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

                const SizedBox(height: HBotSpacing.space3),

                // Toggle switch — centered
                SizedBox(
                  height: 32,
                  width: 52,
                  child: FittedBox(
                    child: Switch(
                      value: widget.isOn,
                      onChanged: _unreachable ? null : widget.onToggle,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
