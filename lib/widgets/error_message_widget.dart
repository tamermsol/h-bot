import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnectivityIssue ? Icons.wifi_off : Icons.error_outline,
            size: 48,
            color: const Color(0xFFFF9500),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
