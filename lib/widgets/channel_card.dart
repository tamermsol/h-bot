import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'design_system.dart';

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
      child: HBotCard(
        borderRadius: 18,
        borderColor: isOn ? HBotColors.glassBorderActive : null,
        padding: const EdgeInsets.all(HBotSpacing.space3),
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isOn
                          ? HBotColors.primary.withOpacity(0.08)
                          : HBotColors.glassBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _icon,
                      size: 20,
                      color: isOn ? HBotColors.primary : HBotColors.textMuted,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    width: 48,
                    child: FittedBox(
                      child: Switch(
                        value: isOn,
                        onChanged: canControl ? onToggle : null,
                        activeColor: HBotColors.primary,
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
                  if (onLongPress != null)
                    GestureDetector(
                      onTap: onLongPress,
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
                isOn ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'Readex Pro',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isOn
                      ? HBotColors.primary
                      : HBotColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
