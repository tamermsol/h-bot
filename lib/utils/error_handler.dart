import 'package:flutter/foundation.dart';

/// User-friendly error handler that hides technical details from end users
class ErrorHandler {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return 'Something went wrong. Please try again.';
    }

    final errorString = error.toString().toLowerCase();

    // Network/connectivity errors
    if (_isNetworkError(errorString)) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Authentication errors
    if (_isAuthError(errorString)) {
      return 'Authentication failed. Please sign in again.';
    }

    // Timeout errors
    if (_isTimeoutError(errorString)) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Permission errors
    if (_isPermissionError(errorString)) {
      return 'Access denied. Please check your permissions.';
    }

    // Generic fallback - never show technical details to users
    return 'Unable to complete request. Please try again later.';
  }

  /// Check if error is network-related
  static bool _isNetworkError(String errorString) {
    return errorString.contains('socketexception') ||
        errorString.contains('no address associated') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network') ||
        errorString.contains('unreachable') ||
        errorString.contains('no route') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection failed');
  }

  /// Check if error is authentication-related
  static bool _isAuthError(String errorString) {
    return errorString.contains('authentication') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('invalid credentials') ||
        errorString.contains('token');
  }

  /// Check if error is timeout-related
  static bool _isTimeoutError(String errorString) {
    return errorString.contains('timeout') ||
        errorString.contains('timed out') ||
        errorString.contains('deadline exceeded');
  }

  /// Check if error is permission-related
  static bool _isPermissionError(String errorString) {
    return errorString.contains('permission') ||
        errorString.contains('access denied') ||
        errorString.contains('forbidden');
  }

  /// Log error for debugging (only in debug mode)
  static void logError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    if (kDebugMode) {
      debugPrint('❌ Error${context != null ? " in $context" : ""}: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Check if device has internet connectivity issue
  static bool isConnectivityIssue(dynamic error) {
    if (error == null) return false;
    return _isNetworkError(error.toString().toLowerCase());
  }
}
