import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
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
        color: context.isDark ? HBotColors.cardDark : HBotColors.neutral800,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
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
              color: HBotColors.textOnPrimary,
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
                  borderRadius: BorderRadius.circular(HBotRadius.small),
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
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
