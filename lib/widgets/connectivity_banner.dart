import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Connectivity Banner per design spec
/// Slim banner with success green / error red, slide-down animation
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
      offset: isOnline ? const Offset(0, -1) : Offset.zero,
      duration: HBotDurations.medium,
      curve: HBotCurves.standard,
      child: AnimatedOpacity(
        opacity: isOnline ? 0.0 : 1.0,
        duration: HBotDurations.medium,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: HBotSpacing.space4,
          ),
          decoration: BoxDecoration(
            color: isOnline ? HBotColors.success : HBotColors.error,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: HBotSpacing.space2),
              Flexible(
                child: Text(
                  message ?? (isOnline ? 'Connected' : 'No internet connection'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 13,
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
