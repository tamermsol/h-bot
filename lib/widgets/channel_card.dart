import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'design_system.dart';

/// Individual channel control card — used in ChannelGrid
/// Compact card with icon, name, state label. Tap icon to toggle.
class ChannelCard extends StatefulWidget {
  final int channelNumber;
  final String channelName;
  final String channelType; // 'light' or 'switch'
  final bool isOn;
  final bool canControl;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onLongPress;

  const ChannelCard({
    super.key,
    required this.channelNumber,
    required this.channelName,
    this.channelType = 'light',
    required this.isOn,
    this.canControl = true,
    required this.onToggle,
    this.onLongPress,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _isPressed = false;
  bool _isToggling = false;

  IconData get _icon =>
      widget.channelType == 'light' ? Icons.lightbulb : Icons.power_settings_new;

  void _handleToggle() {
    if (!widget.canControl) return;
    setState(() => _isToggling = true);
    widget.onToggle(!widget.isOn);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _isToggling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canControl ? _handleToggle : null,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: HBotDurations.fast,
        curve: HBotCurves.standard,
        child: HBotCard(
          borderRadius: 18,
          borderColor: widget.isOn ? HBotColors.glassBorderActive : null,
          padding: const EdgeInsets.all(HBotSpacing.space3),
          child: Opacity(
            opacity: widget.canControl ? 1.0 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon — press scales + glows when on
                AnimatedScale(
                  scale: _isPressed ? 0.80 : 1.0,
                  duration: HBotDurations.fast,
                  curve: HBotCurves.standard,
                  child: AnimatedContainer(
                    duration: HBotDurations.medium,
                    curve: HBotCurves.standard,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isOn
                          ? HBotColors.primary.withOpacity(0.18)
                          : HBotColors.glassBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: widget.isOn
                          ? [
                              BoxShadow(
                                color: HBotColors.primary.withOpacity(0.28),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: _isToggling
                        ? Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    HBotColors.primary),
                              ),
                            ),
                          )
                        : Icon(
                            _icon,
                            size: 20,
                            color: widget.isOn
                                ? HBotColors.primary
                                : HBotColors.textMuted,
                          ),
                  ),
                ),

                const SizedBox(height: HBotSpacing.space2),

                // Channel name + edit
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.channelName,
                        style: const TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onLongPress != null)
                      GestureDetector(
                        onTap: widget.onLongPress,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: HBotColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 2),

                // State label
                Text(
                  widget.isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontFamily: 'Readex Pro',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: widget.isOn
                        ? HBotColors.primary
                        : HBotColors.textMuted,
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
