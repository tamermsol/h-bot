import 'package:flutter/material.dart';
import '../utils/error_handler.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

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
        color: context.hCard,
        borderRadius: HBotRadius.mediumRadius,
        border: Border.all(color: context.hBorder),
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
            style: TextStyle(
              color: context.hTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: HBotSpacing.space4),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.get('error_message_try_again')),
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.warning,
                foregroundColor: HBotColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space6,
                  vertical: HBotSpacing.space3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: HBotRadius.smallRadius,
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
              child: Text(message, style: const TextStyle(color: HBotColors.textOnPrimary)),
            ),
          ],
        ),
        backgroundColor: HBotColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: HBotRadius.smallRadius),
      ),
    );
  }
}
