import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// iOS-specific WiFi hotspot service using NEHotspotConfigurationManager
/// Bypasses captive portal detection and allows programmatic WiFi switching
class IOSHotspotService {
  static const MethodChannel _channel = MethodChannel('com.mb.hbot/hotspot');

  /// Join a WiFi network programmatically (bypasses captive portal)
  /// For device APs like hbot-XXXX, pass no password
  static Future<HotspotResult> joinNetwork(String ssid, {String? password}) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('joinNetwork', {
        'ssid': ssid,
        'password': password,
        'isWEP': false,
      });
      
      if (result == null) {
        return HotspotResult(success: false, message: 'No response from platform');
      }
      
      return HotspotResult(
        success: result['success'] as bool? ?? false,
        message: result['message'] as String? ?? 'Unknown result',
      );
    } on PlatformException catch (e) {
      debugPrint('HotspotService joinNetwork error: ${e.message}');
      return HotspotResult(success: false, message: e.message ?? 'Platform error');
    } catch (e) {
      debugPrint('HotspotService joinNetwork error: $e');
      return HotspotResult(success: false, message: 'Failed to join network: $e');
    }
  }

  /// Leave/forget a WiFi network (returns to home WiFi automatically)
  static Future<HotspotResult> leaveNetwork(String ssid) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('leaveNetwork', {
        'ssid': ssid,
      });
      
      if (result == null) {
        return HotspotResult(success: false, message: 'No response from platform');
      }
      
      return HotspotResult(
        success: result['success'] as bool? ?? false,
        message: result['message'] as String? ?? 'Unknown result',
      );
    } catch (e) {
      debugPrint('HotspotService leaveNetwork error: $e');
      return HotspotResult(success: false, message: 'Failed to leave network: $e');
    }
  }

  /// Request precise (full accuracy) location — required for SSID reading on iOS 14+
  static Future<bool> requestPreciseLocation() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPreciseLocation');
      return result ?? false;
    } catch (e) {
      debugPrint('HotspotService requestPreciseLocation error: $e');
      return false;
    }
  }

  /// Get current SSID using NEHotspot API
  static Future<String?> getCurrentSSID() async {
    try {
      return await _channel.invokeMethod<String?>('getCurrentSSID');
    } catch (e) {
      debugPrint('HotspotService getCurrentSSID error: $e');
      return null;
    }
  }
}

class HotspotResult {
  final bool success;
  final String message;

  HotspotResult({required this.success, required this.message});
}
