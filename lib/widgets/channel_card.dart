import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Individual channel control card — used in ChannelGrid
/// Compact card with icon, name, state label, and toggle
class ChannelCard extends StatelessWidget {
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

  IconData get _icon =>
      channelType == 'light' ? Icons.lightbulb : Icons.power_settings_new;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canControl ? () => onToggle(!isOn) : null,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: HBotDurations.medium,
        curve: HBotCurves.standard,
        padding: const EdgeInsets.all(HBotSpacing.space3),
        decoration: BoxDecoration(
          color: context.hCard,
          borderRadius: HBotRadius.mediumRadius,
          border: Border(
            left: BorderSide(
              color: isOn ? HBotColors.primary : context.hBorder,
              width: isOn ? 3 : 1,
            ),
            top: BorderSide(color: context.hBorder, width: 1),
            right: BorderSide(color: context.hBorder, width: 1),
            bottom: BorderSide(color: context.hBorder, width: 1),
          ),
        ),
        child: Opacity(
          opacity: canControl ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: icon + mini toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    _icon,
                    size: 24,
                    color: isOn ? HBotColors.primary : HBotColors.iconDefault,
                  ),
                  SizedBox(
                    height: 28,
                    width: 44,
                    child: FittedBox(
                      child: Switch(
                        value: isOn,
                        onChanged: canControl ? onToggle : null,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: HBotSpacing.space2),

              // Channel name + edit
              Row(
                children: [
                  Expanded(
                    child: Text(
                      channelName,
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.hTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onLongPress != null)
                    GestureDetector(
                      onTap: onLongPress,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: context.hTextTertiary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 2),

              // State label
              Text(
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isOn
                      ? HBotColors.primary
                      : context.hTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
