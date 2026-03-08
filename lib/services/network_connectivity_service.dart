import 'dart:async';
import 'dart:io' show InternetAddress, Socket;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for checking network connectivity and Supabase reachability
class NetworkConnectivityService {
  static const Duration _timeout = Duration(seconds: 10);
  static const String _supabaseHost = 'mvmvqycvorstsftcldzs.supabase.co';

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnectivity() async {
    try {
      if (kIsWeb) {
        // On web we cannot use low-level DNS lookups; use a simple HTTP probe
        final response = await http
            .get(Uri.https('google.com'), headers: {'User-Agent': 'hbot-app'})
            .timeout(_timeout);
        return response.statusCode == 200;
      }

      // Try to resolve DNS first
      final addresses = await InternetAddress.lookup('google.com');
      if (addresses.isEmpty) {
        debugPrint('❌ DNS resolution failed for google.com');
        return false;
      }

      // Try to make a simple HTTP request
      final response = await http
          .get(Uri.https('google.com'), headers: {'User-Agent': 'hbot-app'})
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Internet connectivity check failed: $e');
      return false;
    }
  }

  /// Check if Supabase is reachable with a simple query
  static Future<bool> isSupabaseReachable() async {
    try {
      debugPrint('🔍 Checking Supabase connectivity...');

      if (!kIsWeb) {
        // First try DNS resolution
        final addresses = await InternetAddress.lookup(_supabaseHost);
        if (addresses.isEmpty) {
          debugPrint('❌ DNS resolution failed for $_supabaseHost');
          return false;
        }
        debugPrint(
          '✅ DNS resolved for $_supabaseHost: ${addresses.first.address}',
        );
      }

      // Try a simple authenticated query to test both connectivity and auth
      final supabase = Supabase.instance.client;
      await supabase
          .from('devices')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));

      debugPrint('✅ Supabase connectivity verified');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connectivity check failed: $e');
      return false;
    }
  }

  /// Check if Supabase is reachable via HTTP health endpoint
  static Future<bool> isSupabaseHttpReachable() async {
    try {
      debugPrint('🔍 Checking Supabase HTTP connectivity...');

      // Try to reach Supabase health endpoint
      final response = await http
          .get(
            Uri.https(_supabaseHost, '/rest/v1/'),
            headers: {'User-Agent': 'hbot-app', 'Accept': 'application/json'},
          )
          .timeout(_timeout);

      debugPrint('📡 Supabase response: ${response.statusCode}');

      // Supabase returns 401 for unauthenticated requests to /rest/v1/
      // This is expected and means the service is reachable
      return response.statusCode == 401 || response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Supabase connectivity check failed: $e');
      return false;
    }
  }

  /// Get network connectivity status with detailed information
  static Future<ConnectivityStatus> getDetailedConnectivityStatus() async {
    final hasInternet = await hasInternetConnectivity();

    if (!hasInternet) {
      return ConnectivityStatus(
        hasInternet: false,
        isSupabaseReachable: false,
        errorMessage: 'No internet connection detected',
      );
    }

    final supabaseReachable = await isSupabaseReachable();

    if (!supabaseReachable) {
      return ConnectivityStatus(
        hasInternet: true,
        isSupabaseReachable: false,
        errorMessage:
            'Internet available but Supabase backend is not reachable. This could be due to:\n'
            '• DNS resolution issues\n'
            '• Firewall blocking the connection\n'
            '• Network restrictions\n'
            '• Temporary service outage',
      );
    }

    return ConnectivityStatus(
      hasInternet: true,
      isSupabaseReachable: true,
      errorMessage: null,
    );
  }

  /// Test alternative DNS servers
  static Future<bool> testAlternativeDNS() async {
    final dnsServers = [
      '8.8.8.8', // Google DNS
      '1.1.1.1', // Cloudflare DNS
      '208.67.222.222', // OpenDNS
    ];

    for (final dns in dnsServers) {
      try {
        debugPrint('🔍 Testing DNS server: $dns');
        final socket = await Socket.connect(
          dns,
          53,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        debugPrint('✅ DNS server $dns is reachable');
        return true;
      } catch (e) {
        debugPrint('❌ DNS server $dns failed: $e');
      }
    }

    return false;
  }

  /// Retry operation with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 2),
    double backoffMultiplier = 2.0,
  }) async {
    Duration delay = initialDelay;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }

        debugPrint('🔄 Attempt ${attempt + 1} failed: $e');
        debugPrint('⏳ Retrying in ${delay.inSeconds}s...');

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }

    throw Exception('Max retries exceeded');
  }
}

/// Network connectivity status information
class ConnectivityStatus {
  final bool hasInternet;
  final bool isSupabaseReachable;
  final String? errorMessage;

  const ConnectivityStatus({
    required this.hasInternet,
    required this.isSupabaseReachable,
    this.errorMessage,
  });

  bool get isFullyConnected => hasInternet && isSupabaseReachable;

  @override
  String toString() {
    return 'ConnectivityStatus(hasInternet: $hasInternet, isSupabaseReachable: $isSupabaseReachable, error: $errorMessage)';
  }
}
