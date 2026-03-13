import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Banner that shows when device is offline
class ConnectivityBanner extends StatelessWidget {
  final bool isOnline;

  const ConnectivityBanner({required this.isOnline, super.key});

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: HBotSpacing.space4),
      color: HBotColors.warning,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet connection',
              style: TextStyle(
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
    );
  }
}
