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
  bool _isToggling = false;

  Color get _activeColor => widget.deviceColor ?? HBotColors.primary;
  bool get _unreachable => widget.isOnline == false;

  void _handleToggle(bool value) {
    setState(() => _isToggling = true);
    widget.onToggle(value);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Success green for active status text
    const successColor = Color(0xFF34D399);

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
            color: _isPressed
                ? HBotColors.glassBackgroundHover
                : HBotColors.glassBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isOn
                  ? HBotColors.glassBorderActive
                  : HBotColors.glassBorder,
              width: 1,
            ),
          ),
          child: Opacity(
            opacity: _unreachable ? 0.5 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Device icon with background container
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.isOn
                            ? _activeColor.withOpacity(0.15)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.isOn ? _activeColor : HBotColors.textMuted,
                        size: 24,
                      ),
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
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.isOn ? successColor : HBotColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                if (widget.roomName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.roomName!,
                    style: const TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: HBotColors.textMuted,
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
                  child: _isToggling
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                            ),
                          ),
                        )
                      : FittedBox(
                          child: Switch(
                            value: widget.isOn,
                            onChanged: _unreachable ? null : _handleToggle,
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
