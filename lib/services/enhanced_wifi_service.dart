import '../services/platform_helper.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'wifi_permission_service.dart';
import 'ios_hotspot_service.dart';
import '../models/tasmota_device_info.dart';
import '../utils/channel_detection_utils.dart';

/// Wi-Fi information model
class WifiInfo {
  final String? ssid;
  final String? bssid;
  final bool is24GHz;
  final String? ip;
  final int? frequency;

  WifiInfo({
    this.ssid,
    this.bssid,
    required this.is24GHz,
    this.ip,
    this.frequency,
  });
}

/// Enhanced Wi-Fi service with proper permission gating and modern Android APIs
class EnhancedWiFiService {
  static const MethodChannel _channel = MethodChannel('enhanced_wifi_service');
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Get current Wi-Fi SSID with proper permission gating
  /// Returns null if SSID cannot be read (instead of throwing exception)
  /// This allows graceful fallback to manual SSID entry
  Future<String?> getCurrentSSID() async {
    // Check permissions first
    final permissionStatus = await WiFiPermissionService.checkPermissions();
    if (!permissionStatus.isGranted) {
      // Return null instead of throwing - allow manual entry
      debugPrint('WiFi permissions not granted: ${permissionStatus.message}');
      return null;
    }

    try {
      if (isAndroid) {
        // Use modern API for Android 10+
        final wifiInfo = await getCurrentWifiInfo();
        if (wifiInfo == null || wifiInfo.ssid == null) {
          // Return null instead of throwing - allow manual entry
          debugPrint('Wi-Fi SSID not available from getCurrentWifiInfo');
          return null;
        }

        // Check for <unknown ssid> or empty
        final ssid = wifiInfo.ssid!;
        if (ssid == '<unknown ssid>' || ssid.isEmpty || ssid == '""') {
          debugPrint('Wi-Fi SSID is unknown or empty: $ssid');
          return null;
        }

        return ssid;
      } else if (isIOS) {
        // iOS: Try native NEHotspot API first (more reliable), fallback to network_info_plus
        final nativeSSID = await IOSHotspotService.getCurrentSSID();
        if (nativeSSID != null && nativeSSID.isNotEmpty) {
          return nativeSSID;
        }
        
        // Fallback to network_info_plus
        final ssid = await _networkInfo.getWifiName();
        if (ssid == null || ssid == '<unknown ssid>' || ssid.isEmpty) {
          debugPrint('Wi-Fi SSID not available on iOS');
          return null;
        }
        return ssid.replaceAll('"', '');
      } else {
        return null;
      }
    } catch (e) {
      // Return null instead of throwing - allow manual entry
      debugPrint('Error reading Wi-Fi SSID: $e');
      return null;
    }
  }

  /// Get current Wi-Fi information (Android 10+ compatible)
  Future<WifiInfo?> getCurrentWifiInfo() async {
    if (isIOS) {
      // iOS: Use network_info_plus for available information
      try {
        final ssid = await _networkInfo.getWifiName();
        final bssid = await _networkInfo.getWifiBSSID();
        final ip = await _networkInfo.getWifiIP();

        return WifiInfo(
          ssid: ssid?.replaceAll('"', ''),
          bssid: bssid,
          is24GHz: false, // iOS doesn't provide frequency info easily
          ip: ip,
          frequency: null,
        );
      } catch (e) {
        debugPrint('Error getting Wi-Fi info on iOS: $e');
        return null;
      }
    }

    if (!isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCurrentWifi',
      );
      if (result == null) return null;

      return WifiInfo(
        ssid: result['ssid'] as String?,
        bssid: result['bssid'] as String?,
        is24GHz: result['is24GHz'] as bool? ?? false,
        ip: result['ip'] as String?,
        frequency: result['frequency'] as int?,
      );
    } catch (e) {
      debugPrint('Error getting Wi-Fi info: $e');
      return null;
    }
  }

  /// Check if Location Services are enabled (required for SSID reading on Android 10-12 and iOS)
  Future<bool> isLocationEnabled() async {
    if (isIOS) {
      // iOS: Check location services
      try {
        return await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        debugPrint('Error checking location status on iOS: $e');
        return true;
      }
    }

    if (!isAndroid) return true;

    try {
      final result = await _channel.invokeMethod<bool>('isLocationEnabled');
      return result ?? true;
    } catch (e) {
      debugPrint('Error checking location status: $e');
      return true;
    }
  }

  /// Check if currently connected to an hbot device AP
  Future<bool> isConnectedToHbotAP() async {
    try {
      final ssid = await getCurrentSSID();
      return ssid?.toLowerCase().startsWith('hbot') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Scan for available hbot device APs
  Future<List<String>> scanForHbotAPs() async {
    // Check permissions first
    final permissionStatus = await WiFiPermissionService.checkPermissions();
    if (!permissionStatus.isGranted) {
      throw WiFiException(
        'Cannot scan for Wi-Fi networks: ${permissionStatus.message}',
        type: WiFiExceptionType.permissionDenied,
      );
    }

    try {
      if (isAndroid) {
        // Use platform channel for Android Wi-Fi scanning
        final result = await _channel.invokeMethod('scanForHbotAPs');
        return List<String>.from(result ?? []);
      } else if (isIOS) {
        // iOS: Cannot scan Wi-Fi networks programmatically
        // Return empty list - user will need to manually select or connect
        debugPrint(
          'Wi-Fi scanning not available on iOS - user must manually connect',
        );
        return [];
      } else {
        // Other platforms
        return [];
      }
    } catch (e) {
      throw WiFiException(
        'Failed to scan for device networks: $e',
        type: WiFiExceptionType.scanFailed,
      );
    }
  }

  /// Connect to an hbot device AP using modern Android APIs
  Future<WiFiConnectionResult> connectToHbotAP(String ssid) async {
    // Check permissions first
    final permissionStatus = await WiFiPermissionService.checkPermissions();
    if (!permissionStatus.isGranted) {
      throw WiFiException(
        'Cannot connect to Wi-Fi: ${permissionStatus.message}',
        type: WiFiExceptionType.permissionDenied,
      );
    }

    if (isIOS) {
      // iOS: Use NEHotspotConfigurationManager to join device AP programmatically
      // This bypasses captive portal detection
      debugPrint('🍎 iOS: Using NEHotspotConfigurationManager to join $ssid');
      final hotspotResult = await IOSHotspotService.joinNetwork(ssid);
      
      if (hotspotResult.success) {
        debugPrint('✅ iOS: Successfully joined $ssid');
        // Wait for connection to stabilize
        await Future.delayed(const Duration(seconds: 2));
        return WiFiConnectionResult(
          success: true,
          message: 'Connected to $ssid',
        );
      } else {
        debugPrint('❌ iOS: Failed to join $ssid: ${hotspotResult.message}');
        return WiFiConnectionResult(
          success: false,
          message: hotspotResult.message,
          requiresManualConnection: hotspotResult.message.contains('cancelled'),
        );
      }
    }

    if (!isAndroid) {
      return WiFiConnectionResult(
        success: false,
        message: 'Platform not supported',
      );
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 29) {
        // Android 10+ - Use WifiNetworkSpecifier
        final result = await _channel.invokeMethod('connectToHbotAPModern', {
          'ssid': ssid,
          'timeout': 30000, // 30 seconds
        });

        return WiFiConnectionResult.fromMap(Map<String, dynamic>.from(result));
      } else {
        // Android 9 and below - Use legacy method
        final result = await _channel.invokeMethod('connectToHbotAPLegacy', {
          'ssid': ssid,
          'timeout': 30000,
        });

        return WiFiConnectionResult.fromMap(Map<String, dynamic>.from(result));
      }
    } catch (e) {
      throw WiFiException(
        'Failed to connect to device network: $e',
        type: WiFiExceptionType.connectionFailed,
      );
    }
  }

  /// Disconnect from hbot device AP and return to normal Wi-Fi with automatic retry
  Future<WiFiConnectionResult> disconnectFromHbotAP() async {
    try {
      if (isAndroid) {
        await _channel.invokeMethod('disconnectFromHbotAP');

        // Wait for the system to reconnect to the original network with retry logic
        final hasInternet = await _verifyInternetConnectivityWithRetry();

        return WiFiConnectionResult(
          success: hasInternet,
          message: hasInternet
              ? 'Successfully returned to original network'
              : 'Failed to restore internet connection after multiple attempts. Please manually check your Wi-Fi settings.',
        );
      } else if (isIOS) {
        // iOS: Use NEHotspotConfigurationManager to remove the device AP config
        // This causes iOS to automatically return to the previous (home) network
        debugPrint('🍎 iOS: Removing device AP configuration to return to home network');
        
        // Get current SSID to know what device network to remove
        final currentSSID = await getCurrentSSID();
        if (currentSSID != null && currentSSID.toLowerCase().startsWith('hbot')) {
          await IOSHotspotService.leaveNetwork(currentSSID);
          debugPrint('✅ iOS: Removed $currentSSID configuration');
        }
        
        // Wait for iOS to reconnect to home network
        await Future.delayed(const Duration(seconds: 3));
        
        final hasInternet = await _verifyInternetConnectivityWithRetry();

        return WiFiConnectionResult(
          success: hasInternet,
          message: hasInternet
              ? 'Successfully returned to home network'
              : 'Reconnecting to home network...',
          requiresManualConnection: !hasInternet,
        );
      } else {
        return WiFiConnectionResult(
          success: false,
          message: 'Platform not supported',
        );
      }
    } catch (e) {
      return WiFiConnectionResult(
        success: false,
        message: 'Failed to disconnect from device AP: $e',
      );
    }
  }

  /// Reconnect to user's Wi-Fi network after provisioning device
  /// Uses WifiNetworkSuggestion on Android 10+ for automatic reconnection
  Future<WiFiConnectionResult> reconnectToUserWifi({
    required String ssid,
    required String password,
  }) async {
    try {
      if (isIOS) {
        // iOS: Remove device AP config (if any), then iOS auto-reconnects to home WiFi
        // We don't need to explicitly join the home network - just leave the device AP
        debugPrint('🍎 iOS: Ensuring return to home network $ssid');
        
        final currentSSID = await getCurrentSSID();
        if (currentSSID != null && currentSSID.toLowerCase().startsWith('hbot')) {
          await IOSHotspotService.leaveNetwork(currentSSID);
          debugPrint('✅ iOS: Removed device AP, waiting for home WiFi reconnection...');
          await Future.delayed(const Duration(seconds: 3));
        }
        
        // Verify we're back on the home network
        final hasInternet = await _verifyInternetConnectivityWithRetry();
        return WiFiConnectionResult(
          success: hasInternet,
          message: hasInternet
              ? 'Reconnected to $ssid'
              : 'Waiting for WiFi reconnection...',
        );
      }

      if (!isAndroid) {
        return WiFiConnectionResult(
          success: false,
          message: 'Platform not supported',
        );
      }

      debugPrint('🔄 Reconnecting to user Wi-Fi: $ssid');

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'reconnectToUserWifi',
        {'ssid': ssid, 'password': password},
      );

      if (result == null) {
        return WiFiConnectionResult(
          success: false,
          message: 'No response from platform',
        );
      }

      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Unknown result';

      if (success) {
        debugPrint('✅ Reconnection initiated: $message');

        // Wait a moment for the connection to establish
        await Future.delayed(const Duration(seconds: 3));

        // Verify internet connectivity
        final hasInternet = await _verifyInternetConnectivityWithRetry();

        return WiFiConnectionResult(
          success: hasInternet,
          message: hasInternet
              ? 'Successfully reconnected to $ssid'
              : 'Reconnection initiated but internet not yet available. Please wait...',
        );
      } else {
        return WiFiConnectionResult(success: false, message: message);
      }
    } catch (e) {
      debugPrint('❌ Error reconnecting to user Wi-Fi: $e');
      return WiFiConnectionResult(
        success: false,
        message: 'Failed to reconnect: $e',
      );
    }
  }

  /// Verify internet connectivity with automatic retry and progressive delays
  Future<bool> _verifyInternetConnectivityWithRetry() async {
    const maxAttempts = 6;
    const baseDelay = Duration(seconds: 3);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Progressive delay: 3s, 5s, 8s, 12s, 15s, 20s
        final delay = Duration(
          seconds: (baseDelay.inSeconds * (1 + (attempt - 1) * 0.7)).round(),
        );

        if (attempt > 1) {
          await Future.delayed(delay);
        } else {
          // Initial delay for first attempt
          await Future.delayed(baseDelay);
        }

        // Try multiple endpoints for better reliability
        final hasInternet = await _testMultipleEndpoints();

        if (hasInternet) {
          return true;
        }

        // Log attempt for debugging
        debugPrint(
          'Network connectivity attempt $attempt/$maxAttempts failed, retrying...',
        );
      } catch (e) {
        debugPrint(
          'Network connectivity attempt $attempt failed with error: $e',
        );
      }
    }

    return false;
  }

  /// Test multiple endpoints for better connectivity verification
  Future<bool> _testMultipleEndpoints() async {
    final endpoints = [
      'https://google.com',
      'https://cloudflare.com',
      'https://httpbin.org/status/200',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(Uri.parse(endpoint))
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        // Try next endpoint
        continue;
      }
    }

    return false;
  }

  /// Provision device with Wi-Fi credentials using web interface
  /// Uses POST with application/x-www-form-urlencoded for reliability
  /// Includes retry logic for better reliability
  Future<WiFiProvisioningResponse> provisionWiFi({
    required String ssid,
    required String password,
    String? hostname,
  }) async {
    // Use proper URL encoding (not custom encoding)
    final encodedSSID = Uri.encodeQueryComponent(ssid);
    final encodedPassword = Uri.encodeQueryComponent(password);

    // Build form body for POST request
    final body = 's1=$encodedSSID&p1=$encodedPassword&save=';

    debugPrint('🔧 Provisioning WiFi to SSID: $ssid');
    debugPrint('📡 POST body: $body');

    final uri = Uri.parse('http://192.168.4.1/wi');

    // Retry logic: Some devices need a moment after binding
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          debugPrint('🔄 Retry attempt $attempt/3');
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }

        // Use POST with proper form encoding (more reliable than GET)
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        debugPrint(
          '📡 Provisioning response (attempt $attempt): ${response.statusCode}',
        );

        // Accept 200 or 302 (redirect) as success
        if (response.statusCode == 200 || response.statusCode == 302) {
          debugPrint(
            '✅ WiFi credentials sent successfully on attempt $attempt',
          );
          debugPrint(
            '📄 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );

          // Give the device a moment to save and start rebooting
          await Future.delayed(const Duration(seconds: 2));

          return WiFiProvisioningResponse(
            success: true,
            message:
                'Wi-Fi credentials sent successfully. Device will restart and connect to your network.',
            deviceIp: '192.168.4.1',
          );
        } else if (attempt < 3) {
          debugPrint('⚠️ HTTP ${response.statusCode}, will retry...');
          continue;
        } else {
          return WiFiProvisioningResponse(
            success: false,
            message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        debugPrint('❌ Provisioning attempt $attempt failed: $e');
        if (attempt < 3) {
          continue; // Retry
        } else {
          return WiFiProvisioningResponse(
            success: false,
            message: 'Failed to provision device after 3 attempts: $e',
          );
        }
      }
    }

    // Should never reach here, but just in case
    return WiFiProvisioningResponse(
      success: false,
      message: 'Provisioning failed unexpectedly',
    );
  }

  /// Provision device with Wi-Fi credentials using Tasmota commands (fallback method)
  Future<WiFiProvisioningResponse> provisionWiFiTasmota({
    required String ssid,
    required String password,
    String? hostname,
  }) async {
    try {
      final request = WiFiProvisioningRequest(
        ssid: ssid,
        password: password,
        hostname: hostname,
      );

      final response = await http
          .post(
            Uri.parse('http://192.168.4.1/cm'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'cmnd=Backlog SSID1 ${request.ssid}; Password1 ${request.password}; WifiConfig 2; SaveData; Restart 1',
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Increased timeout for device processing

      if (response.statusCode == 200) {
        return WiFiProvisioningResponse(
          success: true,
          message: 'Wi-Fi credentials sent successfully (Tasmota method)',
          deviceIp: '192.168.4.1',
        );
      } else {
        return WiFiProvisioningResponse(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return WiFiProvisioningResponse(
        success: false,
        message: 'Failed to provision device: $e',
      );
    }
  }

  /// Fetch device information from connected hbot device
  Future<TasmotaDeviceInfo> fetchDeviceInfo() async {
    try {
      // Use Status 0 to get comprehensive device information including StatusSTS
      final response = await http
          .get(
            Uri.parse('http://192.168.4.1/cm?cmnd=Status%200'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['Status'];
        final statusNET = data['StatusNET'] ?? {};

        if (status != null) {
          final deviceName = status['DeviceName'] ?? 'Unknown Device';
          final topic = status['Topic'] ?? 'hbot_unknown';
          final mac = statusNET['Mac'] ?? 'Unknown';
          final hostname =
              statusNET['Hostname'] ??
              deviceName.toLowerCase().replaceAll(' ', '-');

          // Use enhanced channel detection with full status data
          final channels = ChannelDetectionUtils.detectChannelCount(data);

          return TasmotaDeviceInfo(
            ip: '192.168.4.1',
            mac: mac,
            hostname: hostname,
            module: deviceName,
            version: status['Version'] ?? '13.0.0',
            channels: channels,
            topicBase: topic,
            fullTopic: '%prefix%/%topic%/',
            sensors: [],
            status: data, // Pass full status data including StatusSTS
          );
        } else {
          throw 'Invalid response format: Status not found';
        }
      } else {
        throw 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
      }
    } catch (e) {
      throw WiFiException(
        'Failed to fetch device information: $e',
        type: WiFiExceptionType.deviceInfoFailed,
      );
    }
  }
}

/// Wi-Fi connection result
class WiFiConnectionResult {
  final bool success;
  final String message;
  final bool requiresManualConnection;

  WiFiConnectionResult({
    required this.success,
    required this.message,
    this.requiresManualConnection = false,
  });

  factory WiFiConnectionResult.fromMap(Map<String, dynamic> map) {
    return WiFiConnectionResult(
      success: map['success'] ?? false,
      message: map['message'] ?? 'Unknown result',
      requiresManualConnection: map['requiresManualConnection'] ?? false,
    );
  }
}

/// Wi-Fi exception types
enum WiFiExceptionType {
  permissionDenied,
  ssidNotAvailable,
  scanFailed,
  connectionFailed,
  deviceInfoFailed,
  platformNotSupported,
  unknown,
}

/// Wi-Fi exception
class WiFiException implements Exception {
  final String message;
  final WiFiExceptionType type;

  WiFiException(this.message, {required this.type});

  @override
  String toString() => message;
}
