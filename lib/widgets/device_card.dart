import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DeviceCard extends StatelessWidget {
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

  Color get _activeColor => deviceColor ?? HBotColors.primary;

  @override
  Widget build(BuildContext context) {
    final online = isOnline ?? isOn;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: hbotDeviceCardDecoration(isOn: isOn),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon circle + status dot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Device type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isOn
                        ? _activeColor.withOpacity(0.12)
                        : HBotColors.neutral100,
                    borderRadius: HBotRadius.smallRadius,
                  ),
                  child: Icon(
                    icon,
                    color: isOn ? _activeColor : HBotColors.neutral400,
                    size: 22,
                  ),
                ),
                // Toggle switch
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: isOn,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Device name
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isOn ? HBotColors.textPrimaryLight : HBotColors.textSecondaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Value (dimmer %, sensor reading, etc.)
            if (value != null) ...[
              const SizedBox(height: 2),
              Text(
                value!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOn ? _activeColor : HBotColors.textTertiaryLight,
                ),
              ),
            ],

            // Room name or status
            const SizedBox(height: HBotSpacing.space2),
            Row(
              children: [
                hbotStatusDot(isOnline: online, size: 7),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    roomName ?? (online ? 'Online' : 'Offline'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: HBotColors.textTertiaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
