import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';

/// Connectivity Banner per design spec
/// Slim banner: 40px height
/// Online: #22C55E bg, white text "Connected"
/// Offline: #EF4444 bg, white text "No Connection"
/// Slide down animation when appearing, slide up when disappearing
/// 12px/500 text, centered with 16px icon
class ConnectivityBanner extends StatelessWidget {
  final bool isOnline;
  final String? message;

  const ConnectivityBanner({
    required this.isOnline,
    this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset(0, isOnline ? -1 : 0),
      duration: HBotDurations.medium,
      curve: HBotCurves.standard,
      child: AnimatedOpacity(
        opacity: isOnline ? 0.0 : 1.0,
        duration: HBotDurations.medium,
        child: Container(
          width: double.infinity,
          height: 40,
          color: isOnline ? HBotColors.success : HBotColors.error,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnline ? HBotIcons.wifi : HBotIcons.wifiOff,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: HBotSpacing.space2),
              Flexible(
                child: Text(
                  message ??
                      (isOnline ? 'Connected' : 'No Connection'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
