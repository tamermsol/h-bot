import 'dart:async';
import 'dart:convert';
// ...existing imports...
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/tasmota_device_info.dart';
import '../utils/channel_detection_utils.dart';

/// Service for discovering Tasmota devices on the network
class DeviceDiscoveryService {
  static const Duration _discoveryTimeout = Duration(seconds: 30);
  static const Duration _httpTimeout = Duration(seconds: 5);
  static const Duration _sweepDelay = Duration(milliseconds: 50);
  static const int _maxConcurrentRequests = 20;

  final NetworkInfo _networkInfo = NetworkInfo();

  /// Discover devices using multiple methods
  Future<List<DeviceDiscoveryResult>> discoverDevices() async {
    final results = <DeviceDiscoveryResult>[];

    // Run discovery methods in parallel
    final futures = [_discoverViaMDNS(), _discoverViaNetworkSweep()];

    final discoveryResults = await Future.wait(futures);

    // Combine results and remove duplicates
    final ipSet = <String>{};
    for (final resultList in discoveryResults) {
      for (final result in resultList) {
        if (!ipSet.contains(result.ip)) {
          ipSet.add(result.ip);
          results.add(result);
        }
      }
    }

    return results;
  }

  /// Discover devices using mDNS
  Future<List<DeviceDiscoveryResult>> _discoverViaMDNS() async {
    final results = <DeviceDiscoveryResult>[];
    MDnsClient? mdns;

    try {
      mdns = MDnsClient();
      await mdns.start();

      // Use a completer to handle timeout properly
      final completer = Completer<List<DeviceDiscoveryResult>>();
      final timer = Timer(_discoveryTimeout, () {
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      });

      // Look for Tasmota devices with proper timeout handling
      _performMDNSLookup(mdns, results, completer);

      // Wait for either completion or timeout
      final finalResults = await completer.future;
      timer.cancel();

      return finalResults;
    } catch (e) {
      // mDNS discovery failed, continue with other methods
      debugPrint('mDNS discovery error: $e');
      return results;
    } finally {
      try {
        mdns?.stop();
      } catch (e) {
        // Ignore stop errors
      }
    }
  }

  /// Perform mDNS lookup with proper error handling
  void _performMDNSLookup(
    MDnsClient mdns,
    List<DeviceDiscoveryResult> results,
    Completer<List<DeviceDiscoveryResult>> completer,
  ) async {
    try {
      await for (final ptr
          in mdns
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer('_http._tcp.local'),
              )
              .timeout(const Duration(seconds: 10))) {
        if (completer.isCompleted) break;

        try {
          // Look for SRV records to get port and target
          await for (final srv
              in mdns
                  .lookup<SrvResourceRecord>(
                    ResourceRecordQuery.service(ptr.domainName),
                  )
                  .timeout(const Duration(seconds: 3))) {
            if (completer.isCompleted) break;

            try {
              // Look for A records to get IP
              await for (final a
                  in mdns
                      .lookup<IPAddressResourceRecord>(
                        ResourceRecordQuery.addressIPv4(srv.target),
                      )
                      .timeout(const Duration(seconds: 3))) {
                if (completer.isCompleted) break;

                final hostname = srv.target;
                final ip = a.address.address;

                // Check if this looks like a Tasmota device
                if (hostname.toLowerCase().contains('tasmota') ||
                    hostname.toLowerCase().contains('hbot')) {
                  // Test reachability with timeout
                  final isReachable = await _testDeviceReachability(
                    ip,
                  ).timeout(const Duration(seconds: 3), onTimeout: () => false);

                  results.add(
                    DeviceDiscoveryResult(
                      ip: ip,
                      hostname: hostname,
                      isReachable: isReachable,
                      discoveryMethod: 'mdns',
                    ),
                  );
                }
              }
            } catch (e) {
              // Continue with next SRV record
              continue;
            }
          }
        } catch (e) {
          // Continue with next PTR record
          continue;
        }
      }
    } catch (e) {
      // mDNS lookup failed
      debugPrint('mDNS lookup error: $e');
    } finally {
      if (!completer.isCompleted) {
        completer.complete(results);
      }
    }
  }

  /// Discover devices using network sweep
  Future<List<DeviceDiscoveryResult>> _discoverViaNetworkSweep() async {
    final results = <DeviceDiscoveryResult>[];

    try {
      final networkInfo = await _getNetworkInfo().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (networkInfo == null) return results;

      final subnet = networkInfo['subnet']!;

      // Use a completer to handle overall timeout
      final completer = Completer<List<DeviceDiscoveryResult>>();
      final timer = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      });

      // Sweep the network (skip .1 as it's usually the gateway)
      _performNetworkSweep(subnet, results, completer);

      // Wait for either completion or timeout
      final finalResults = await completer.future;
      timer.cancel();

      return finalResults;
    } catch (e) {
      // Network sweep failed
      debugPrint('Network sweep error: $e');
      return results;
    }
  }

  /// Perform network sweep with proper timeout handling
  void _performNetworkSweep(
    String subnet,
    List<DeviceDiscoveryResult> results,
    Completer<List<DeviceDiscoveryResult>> completer,
  ) async {
    try {
      final futures = <Future<DeviceDiscoveryResult?>>[];

      for (int i = 2; i <= 254; i++) {
        if (completer.isCompleted) break;

        final ip = '$subnet.$i';
        futures.add(_checkDeviceAtIP(ip));

        // Limit concurrent requests
        if (futures.length >= _maxConcurrentRequests) {
          try {
            final batchResults = await Future.wait(
              futures,
            ).timeout(const Duration(seconds: 10));
            results.addAll(batchResults.whereType<DeviceDiscoveryResult>());
            futures.clear();

            if (!completer.isCompleted) {
              await Future.delayed(_sweepDelay);
            }
          } catch (e) {
            // Batch failed, clear futures and continue
            futures.clear();
            debugPrint('Network sweep batch error: $e');
          }
        }
      }

      // Process remaining futures
      if (futures.isNotEmpty && !completer.isCompleted) {
        try {
          final batchResults = await Future.wait(
            futures,
          ).timeout(const Duration(seconds: 10));
          results.addAll(batchResults.whereType<DeviceDiscoveryResult>());
        } catch (e) {
          debugPrint('Final network sweep batch error: $e');
        }
      }
    } catch (e) {
      debugPrint('Network sweep execution error: $e');
    } finally {
      if (!completer.isCompleted) {
        completer.complete(results);
      }
    }
  }

  /// Check if a device exists at the given IP
  Future<DeviceDiscoveryResult?> _checkDeviceAtIP(String ip) async {
    try {
      final stopwatch = Stopwatch()..start();
      final isReachable = await _testDeviceReachability(ip);
      stopwatch.stop();

      if (isReachable) {
        return DeviceDiscoveryResult(
          ip: ip,
          isReachable: true,
          responseTime: stopwatch.elapsedMilliseconds,
          discoveryMethod: 'sweep',
        );
      }
    } catch (e) {
      // Device not reachable
    }
    return null;
  }

  /// Test if a device is reachable and looks like a Tasmota device
  Future<bool> _testDeviceReachability(String ip) async {
    try {
      // Try to connect to common Tasmota endpoints with shorter timeout
      final endpoints = ['/cm?cmnd=Status', '/status', '/'];

      for (final endpoint in endpoints) {
        try {
          final response = await http
              .get(Uri.http('$ip:80', endpoint))
              .timeout(const Duration(seconds: 3)); // Shorter timeout

          if (response.statusCode == 200) {
            // Check if response looks like Tasmota
            final body = response.body.toLowerCase();
            if (body.contains('tasmota') ||
                body.contains('status') ||
                body.contains('power') ||
                body.contains('hbot')) {
              return true;
            }
          }
        } catch (e) {
          // Try next endpoint
          continue;
        }
      }
    } catch (e) {
      // Device not reachable
    }
    return false;
  }

  /// Get network information for subnet calculation
  Future<Map<String, String>?> _getNetworkInfo() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) return null;

      // Extract subnet (assume /24)
      final parts = wifiIP.split('.');
      if (parts.length != 4) return null;

      final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

      return {'ip': wifiIP, 'subnet': subnet};
    } catch (e) {
      return null;
    }
  }

  /// Fetch detailed device information from a discovered device
  Future<TasmotaDeviceInfo?> fetchDeviceInfo(String ip) async {
    try {
      // Get device status
      final statusResponse = await http
          .get(Uri.http('$ip:80', '/cm', {'cmnd': 'Status 0'}))
          .timeout(_httpTimeout);

      if (statusResponse.statusCode != 200) {
        throw 'Failed to get device status';
      }

      final statusData =
          jsonDecode(statusResponse.body) as Map<String, dynamic>;

      // Extract device information
      final status = statusData['Status'] ?? statusData;
      final statusNET = statusData['StatusNET'] ?? {};

      final mac = statusNET['Mac'] ?? '';
      final hostname = statusNET['Hostname'] ?? 'tasmota-device';
      final module = status['Module'] ?? 'Unknown';
      final version = status['Version'] ?? 'Unknown';

      // Determine number of channels using enhanced detection
      int channels = ChannelDetectionUtils.detectChannelCount(statusData);

      // Get sensor information AND check for shutter device
      final sensors = <String>[];
      Map<String, dynamic>? status8Data;
      try {
        final sensorResponse = await http
            .get(Uri.http('$ip:80', '/cm', {'cmnd': 'Status 8'}))
            .timeout(_httpTimeout);

        if (sensorResponse.statusCode == 200) {
          final sensorData =
              jsonDecode(sensorResponse.body) as Map<String, dynamic>;
          status8Data = sensorData; // Store for shutter detection
          final statusSNS = sensorData['StatusSNS'] ?? {};
          sensors.addAll(
            statusSNS.keys.where((key) => key != 'Time').cast<String>(),
          );
        }
      } catch (e) {
        // Sensor info not available
      }

      // Check if this is a shutter device using STATUS 8 data
      bool isShutter = false;
      if (status8Data != null) {
        isShutter = ChannelDetectionUtils.isShutterDevice(status8Data);
        if (isShutter) {
          debugPrint('🪟 Device detected as SHUTTER from STATUS 8');
          channels = 1; // Override channel count for shutters
        }
      }

      // Try to get MQTT topic from device using basic status command
      String topicBase = '';
      String fullTopic = '';

      try {
        // Get Topic from basic status command as specified
        final mqttResponse = await http
            .get(Uri.http('$ip:80', '/cm', {'cmnd': 'status'}))
            .timeout(_httpTimeout);

        if (mqttResponse.statusCode == 200) {
          final mqttData =
              jsonDecode(mqttResponse.body) as Map<String, dynamic>;
          final statusSection = mqttData['Status'] ?? {};
          topicBase = statusSection['Topic'] ?? '';

          debugPrint('🔍 Extracted MQTT topic from device: $topicBase');
          debugPrint('📋 Full status response: $mqttData');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to get MQTT topic from device: $e');
        // MQTT info not available, will generate from MAC
      }

      // If no topic found, generate from MAC as fallback
      if (topicBase.isEmpty) {
        topicBase = TasmotaDeviceInfo.generateTopicFromMac(mac);
        debugPrint('🔄 Generated fallback topic from MAC: $topicBase');
      }

      // If no full topic found, use default pattern
      if (fullTopic.isEmpty) {
        fullTopic = '%prefix%/$topicBase/';
      }

      return TasmotaDeviceInfo(
        ip: ip,
        mac: mac,
        hostname: hostname,
        module: module,
        version: version,
        channels: channels,
        sensors: sensors,
        topicBase: topicBase,
        fullTopic: fullTopic,
        status: statusData,
        isShutter: isShutter, // Pass shutter detection flag
      );
    } catch (e) {
      throw 'Failed to fetch device info: $e';
    }
  }

  /// Discover and fetch info for all devices
  Future<List<TasmotaDeviceInfo>> discoverAndFetchDeviceInfo() async {
    final devices = <TasmotaDeviceInfo>[];

    // Discover devices
    final discoveryResults = await discoverDevices();

    // Fetch detailed info for reachable devices
    for (final result in discoveryResults.where((r) => r.isReachable)) {
      try {
        final deviceInfo = await fetchDeviceInfo(result.ip);
        if (deviceInfo != null) {
          devices.add(deviceInfo);
        }
      } catch (e) {
        // Failed to fetch info for this device, continue with others
      }
    }

    return devices;
  }

  /// Manually check a specific IP for a Tasmota device
  Future<TasmotaDeviceInfo?> checkSpecificIP(String ip) async {
    try {
      final isReachable = await _testDeviceReachability(ip);
      if (!isReachable) return null;

      return await fetchDeviceInfo(ip);
    } catch (e) {
      return null;
    }
  }
}
