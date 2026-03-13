import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Device Card per design spec (03-COMPONENT-LIBRARY.md Section 2.1)
/// White bg, 16px radius, 1px border #E8ECF1
/// ON state: 3px left blue accent border, icon = $iconActive
/// OFF state: default border, icon = $iconDefault
/// Shimmer loading state available via isLoading
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

  Color get _activeColor => deviceColor ?? HBotColors.primary;

  @override
  Widget build(BuildContext context) {
    final online = isOnline ?? isOn;
    final bool unreachable = isOnline == false && !isOn;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: HBotDurations.fast,
        curve: HBotCurves.standard,
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: HBotColors.cardLight,
          borderRadius: HBotRadius.largeRadius,
          border: Border.all(
            color: HBotColors.borderLight,
            width: 1,
          ),
        ),
        child: Opacity(
          opacity: unreachable ? 0.5 : 1.0,
          child: Stack(
            children: [
              // Left blue accent border for ON state
              if (isOn)
                Positioned(
                  left: -HBotSpacing.space4,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: HBotColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(HBotRadius.large),
                        bottomLeft: Radius.circular(HBotRadius.large),
                      ),
                    ),
                  ),
                ),

              // Unreachable red dot indicator
              if (unreachable)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: HBotColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // Card content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Device type icon (32px per spec)
                      Icon(
                        icon,
                        color: isOn
                            ? HBotColors.iconActive
                            : HBotColors.iconDefault,
                        size: 32,
                      ),
                      // Toggle switch with gradient track
                      SizedBox(
                        height: 32,
                        child: FittedBox(
                          child: Switch(
                            value: isOn,
                            onChanged: unreachable ? null : onToggle,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: HBotSpacing.space2),

                  // Device name ($titleMedium 16/600)
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HBotColors.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: HBotSpacing.space2),

                  // State text ($bodyMedium 14/400)
                  if (isLoading)
                    // Shimmer placeholder for loading state
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
                      value ?? (isOn ? 'ON' : 'OFF'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isOn
                            ? HBotColors.primary
                            : HBotColors.textSecondaryLight,
                      ),
                    ),

                  const SizedBox(height: HBotSpacing.space2),

                  // Room name or status row
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
            ],
          ),
        ),
      ),
    );
  }
}
