import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';

/// Widget to display user-friendly error messages
class ErrorMessageWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? customMessage;

  const ErrorMessageWidget({
    required this.error,
    this.onRetry,
    this.customMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isConnectivityIssue = ErrorHandler.isConnectivityIssue(error);
    final message = customMessage ?? ErrorHandler.getUserFriendlyMessage(error);

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        borderRadius: HBotRadius.largeRadius,
        border: Border.all(color: HBotColors.borderLight, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnectivityIssue ? Icons.wifi_off : Icons.error_outline,
            size: 48,
            color: HBotColors.warning,
          ),
          const SizedBox(height: HBotSpacing.space4),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: HBotColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: HBotSpacing.space4),
            Container(
              decoration: hbotPrimaryButtonDecoration(),
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: HBotColors.textOnPrimary,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: HBotSpacing.space6,
                    vertical: HBotSpacing.space3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: HBotRadius.mediumRadius,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Snackbar for showing brief error messages
class ErrorSnackBar {
  static void show(BuildContext context, dynamic error) {
    final message = ErrorHandler.getUserFriendlyMessage(error);
    final isConnectivityIssue = ErrorHandler.isConnectivityIssue(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnectivityIssue ? Icons.wifi_off : Icons.error_outline,
              color: HBotColors.textOnPrimary,
              size: 20,
            ),
            const SizedBox(width: HBotSpacing.space3),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HBotColors.textOnPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: HBotColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.smallRadius,
        ),
      ),
    );
  }
}
