import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/platform_helper.dart';
import 'package:http/http.dart' as http;
import '../services/wifi_plugin.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../services/permission_shim.dart';
import '../models/tasmota_device_info.dart';

/// Service for Wi-Fi provisioning of Tasmota devices
class WiFiProvisioningService {
  static const String _deviceApPrefix = 'hbot-';
  static const String _provisioningIp = '192.168.4.1';
  static const int _provisioningPort = 80;
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _httpTimeout = Duration(seconds: 10);

  final NetworkInfo _networkInfo = NetworkInfo();

  /// Check if location permissions are granted (required for Wi-Fi scanning)
  Future<bool> checkPermissions() async {
    if (isAndroid) {
      final locationStatus = await Permission.location.status;
      final nearbyDevicesStatus = await Permission.nearbyWifiDevices.status;

      if (!locationStatus.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) return false;
      }

      if (!nearbyDevicesStatus.isGranted) {
        final result = await Permission.nearbyWifiDevices.request();
        if (!result.isGranted) return false;
      }
    } else if (isIOS) {
      // iOS: Check location permission
      final locationStatus = await Permission.locationWhenInUse.status;

      if (!locationStatus.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) return false;
      }
    }
    return true;
  }

  /// Scan for available Hbot access points
  Future<List<String>> scanForHbotAPs() async {
    try {
      if (!await checkPermissions()) {
        throw 'Location permissions required for Wi-Fi scanning';
      }

      final networks = await WiFiForIoTPlugin.loadWifiList();
      final hbotNetworks = networks
          .where(
            (network) => network.ssid?.startsWith(_deviceApPrefix) ?? false,
          )
          .map((network) => network.ssid ?? '')
          .where((ssid) => ssid.isNotEmpty)
          .toList();

      return hbotNetworks;
    } catch (e) {
      throw 'Failed to scan for Wi-Fi networks: $e';
    }
  }

  /// Connect to a specific Hbot access point
  Future<bool> connectToHbotAP(String ssid) async {
    try {
      if (!await checkPermissions()) {
        throw 'Location permissions required for Wi-Fi connection';
      }

      // Disconnect from current network first
      await WiFiForIoTPlugin.disconnect();
      await Future.delayed(const Duration(seconds: 2));

      // Connect to the Hbot AP (usually no password)
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: '', // Hbot APs are typically open
        joinOnce: true,
        timeoutInSeconds: _connectionTimeout.inSeconds,
      );

      if (!connected) {
        throw 'Failed to connect to $ssid';
      }

      // Wait for connection to stabilize
      await Future.delayed(const Duration(seconds: 3));

      // Verify we can reach the provisioning endpoint
      final reachable = await _testProvisioningEndpoint();
      if (!reachable) {
        throw 'Connected to $ssid but cannot reach provisioning endpoint';
      }

      return true;
    } catch (e) {
      throw 'Failed to connect to Hbot AP: $e';
    }
  }

  /// Test if the provisioning endpoint is reachable
  Future<bool> _testProvisioningEndpoint() async {
    try {
      final response = await http
          .get(Uri.http('$_provisioningIp:$_provisioningPort', '/'))
          .timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Custom URL encoding for device provisioning (more aggressive than Uri.encodeComponent)
  String _encodeForDevice(String value) {
    // Do % replacement first to avoid double-encoding
    return value
        .replaceAll('%', '%25')
        .replaceAll('!', '%21')
        .replaceAll('@', '%40')
        .replaceAll('#', '%23')
        .replaceAll('\$', '%24')
        .replaceAll('^', '%5E')
        .replaceAll('&', '%26')
        .replaceAll('*', '%2A')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('+', '%2B')
        .replaceAll('=', '%3D')
        .replaceAll('[', '%5B')
        .replaceAll(']', '%5D')
        .replaceAll('{', '%7B')
        .replaceAll('}', '%7D')
        .replaceAll('|', '%7C')
        .replaceAll('\\', '%5C')
        .replaceAll(':', '%3A')
        .replaceAll(';', '%3B')
        .replaceAll('"', '%22')
        .replaceAll("'", '%27')
        .replaceAll('<', '%3C')
        .replaceAll('>', '%3E')
        .replaceAll(',', '%2C')
        .replaceAll('?', '%3F')
        .replaceAll('/', '%2F')
        .replaceAll(' ', '%20');
  }

  /// Send Wi-Fi credentials to the device using web interface
  Future<WiFiProvisioningResponse> provisionWiFi({
    required String ssid,
    required String password,
    String? hostname,
  }) async {
    try {
      // Use custom encoding to match device expectations
      final encodedPassword = _encodeForDevice(password);
      final encodedSSID = _encodeForDevice(ssid);

      // Use the web interface format: /wi?s1=SSID&p1=PASSWORD&save=
      final url =
          'http://$_provisioningIp/wi?s1=$encodedSSID&p1=$encodedPassword&save=';

      debugPrint('🔧 Provisioning WiFi with URL: $url');

      final response = await http.get(Uri.parse(url)).timeout(_httpTimeout);

      debugPrint('📡 Provisioning response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Check if the response indicates success
        final responseBody = response.body.toLowerCase();
        if (responseBody.contains('credentials saved') ||
            responseBody.contains('restart') ||
            responseBody.contains('success') ||
            response.body.isNotEmpty) {
          debugPrint('✅ WiFi credentials sent successfully');

          // Give the device a moment to process the credentials
          await Future.delayed(const Duration(seconds: 2));

          return WiFiProvisioningResponse(
            success: true,
            message:
                'Wi-Fi credentials sent successfully. Device will restart and connect to your network.',
          );
        } else {
          return WiFiProvisioningResponse(
            success: false,
            message: 'Device responded but may not have accepted credentials',
          );
        }
      } else {
        return WiFiProvisioningResponse(
          success: false,
          message: 'HTTP ${response.statusCode}: Failed to send credentials',
        );
      }
    } catch (e) {
      debugPrint('❌ WiFi provisioning failed: $e');
      return WiFiProvisioningResponse(
        success: false,
        message: 'Failed to provision Wi-Fi: $e',
      );
    }
  }

  /// Send Wi-Fi credentials to the device using Tasmota commands (fallback method)
  Future<WiFiProvisioningResponse> provisionWiFiTasmota({
    required String ssid,
    required String password,
    String? hostname,
  }) async {
    try {
      // Step 1: Send Wi-Fi configuration
      final configCommand =
          'Backlog SSID1 $ssid;Password1 $password;WifiConfig 2';
      final configResponse = await http
          .get(
            Uri.http('$_provisioningIp:$_provisioningPort', '/cm', {
              'cmnd': configCommand,
            }),
          )
          .timeout(_httpTimeout);

      if (configResponse.statusCode != 200) {
        throw 'Failed to configure Wi-Fi: HTTP ${configResponse.statusCode}';
      }

      // Step 2: Save and restart
      final restartCommand = 'Backlog SaveData;Restart 1';
      final restartResponse = await http
          .get(
            Uri.http('$_provisioningIp:$_provisioningPort', '/cm', {
              'cmnd': restartCommand,
            }),
          )
          .timeout(_httpTimeout);

      if (restartResponse.statusCode != 200) {
        throw 'Failed to restart device: HTTP ${restartResponse.statusCode}';
      }

      return WiFiProvisioningResponse(
        success: true,
        message:
            'Wi-Fi configured successfully (Tasmota method), device restarting',
      );
    } catch (e) {
      return WiFiProvisioningResponse(
        success: false,
        message: 'Failed to provision Wi-Fi: $e',
      );
    }
  }

  /// Get current Wi-Fi network info
  Future<Map<String, String?>> getCurrentNetworkInfo() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiGateway = await _networkInfo.getWifiGatewayIP();

      return {
        'ssid': wifiName?.replaceAll('"', ''), // Remove quotes on Android
        'bssid': wifiBSSID,
        'ip': wifiIP,
        'gateway': wifiGateway,
      };
    } catch (e) {
      throw 'Failed to get network info: $e';
    }
  }

  /// Check if currently connected to a Hbot AP
  Future<bool> isConnectedToHbotAP() async {
    try {
      final networkInfo = await getCurrentNetworkInfo();
      final ssid = networkInfo['ssid'];
      return ssid != null &&
          ssid.toLowerCase().startsWith(_deviceApPrefix.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Get current SSID
  Future<String?> getCurrentSSID() async {
    try {
      final networkInfo = await getCurrentNetworkInfo();
      return networkInfo['ssid'];
    } catch (e) {
      return null;
    }
  }

  /// Disconnect from current network and return to original Wi-Fi
  Future<bool> disconnectFromHbotAP() async {
    try {
      await WiFiForIoTPlugin.disconnect();

      // Wait for the system to reconnect to the original network
      await Future.delayed(const Duration(seconds: 5));

      // Verify we have internet connectivity
      return await _verifyNetworkConnectivity();
    } catch (e) {
      // Disconnect failed
      return false;
    }
  }

  /// Verify network connectivity after disconnection
  Future<bool> _verifyNetworkConnectivity() async {
    try {
      // Try to reach a reliable endpoint
      final response = await http
          .get(Uri.https('google.com'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get the device's current IP on the provisioning network
  Future<String?> getDeviceProvisioningIP() async {
    try {
      if (await isConnectedToHbotAP()) {
        return _provisioningIp;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Send a restart command to the device after provisioning
  Future<bool> restartDevice() async {
    try {
      final response = await http
          .post(Uri.http('$_provisioningIp:$_provisioningPort', '/restart'))
          .timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get device information during provisioning
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final response = await http
          .get(Uri.http('$_provisioningIp:$_provisioningPort', '/info'))
          .timeout(_httpTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Complete provisioning flow
  Future<WiFiProvisioningResponse> completeProvisioning({
    required String deviceSSID,
    required String targetSSID,
    required String targetPassword,
    String? hostname,
  }) async {
    try {
      // Step 1: Connect to device AP
      await connectToHbotAP(deviceSSID);

      // Step 2: Get device info before provisioning
      final deviceInfo = await getDeviceInfo();

      // Step 3: Send Wi-Fi credentials
      final provisioningResult = await provisionWiFi(
        ssid: targetSSID,
        password: targetPassword,
        hostname: hostname,
      );

      if (!provisioningResult.success) {
        return provisioningResult;
      }

      // Step 4: Restart device
      await restartDevice();

      // Step 5: Disconnect from device AP and verify network connectivity
      final networkRestored = await disconnectFromHbotAP();

      if (!networkRestored) {
        return WiFiProvisioningResponse(
          success: false,
          message:
              'Device provisioned but failed to restore network connection. Please check your Wi-Fi settings.',
        );
      }

      return WiFiProvisioningResponse(
        success: true,
        message:
            'Device provisioned successfully and network connection restored',
        deviceIp: deviceInfo?['ip'],
      );
    } catch (e) {
      // Ensure we disconnect from device AP on error
      final networkRestored = await disconnectFromHbotAP();

      final errorMessage = networkRestored
          ? 'Provisioning failed: $e'
          : 'Provisioning failed: $e. Additionally, failed to restore network connection.';

      return WiFiProvisioningResponse(success: false, message: errorMessage);
    }
  }
}
