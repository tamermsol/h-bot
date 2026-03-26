import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

/// Persistent offline banner — sits at top of screen when offline
/// Design: 04-SCREEN-DESIGNS.md §10.2
class ConnectivityBanner extends StatelessWidget {
  final bool isOnline;

  const ConnectivityBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: HBotDurations.medium,
      height: isOnline ? 0 : 36,
      color: HBotColors.warning,
      child: isOnline
          ? const SizedBox.shrink()
          : Center(
              child: Text(
                AppStrings.get('no_internet_connection'),
                style: const TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HBotColors.textOnPrimary,
                ),
              ),
            ),
    );
  }
}
