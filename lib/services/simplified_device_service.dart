import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../models/tasmota_device_info.dart';
import '../services/smart_home_service.dart';
import '../services/enhanced_mqtt_service.dart';
import '../services/network_connectivity_service.dart';
import '../repos/devices_repo.dart';
import '../utils/channel_detection_utils.dart';

/// Service for creating devices immediately after provisioning without LAN discovery
class SimplifiedDeviceService {
  final SmartHomeService _smartHomeService = SmartHomeService();
  final EnhancedMqttService _mqttService = EnhancedMqttService();
  final DevicesRepo _devicesRepo = DevicesRepo();

  /// Create device immediately after provisioning using known MQTT data
  Future<Device> createDeviceFromProvisioning({
    required String homeId,
    String? roomId,
    required String deviceName,
    required String deviceMac,
    required String mqttTopic,
    required int channels,
    String? deviceIp,
    String? hostname,
    String? module,
    String? version,
    Map<String, dynamic>? additionalMeta,
  }) async {
    try {
      debugPrint('🔄 Starting device creation...');

      // Check authentication first
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception(
          'Authentication required. Please log in and try again.',
        );
      }

      // Generate MQTT topic base from MAC if not provided
      final topicBase = mqttTopic.isNotEmpty
          ? mqttTopic
          : TasmotaDeviceInfo.generateTopicFromMac(deviceMac);

      // Determine device type based on channels, module, and additional metadata
      DeviceType deviceType = _determineDeviceType(
        channels,
        module,
        additionalMeta,
      );

      // Determine channel_count (for shutters, always 1)
      int channelCount = deviceType == DeviceType.shutter ? 1 : channels;

      debugPrint(
        '🔍 Device type: ${deviceType.name}, channels: $channels, channel_count: $channelCount',
      );

      // Create derived MQTT bases
      final mqttCmdBase = 'cmnd/$topicBase/';
      final mqttStatBase = 'stat/$topicBase/';
      final mqttTeleBase = 'tele/$topicBase/';

      // Prepare metadata
      final metaJson = <String, dynamic>{
        'mac': deviceMac,
        'mqtt_topic': topicBase,
        'mqtt_cmd_base': mqttCmdBase,
        'mqtt_stat_base': mqttStatBase,
        'mqtt_tele_base': mqttTeleBase,
        'channels': channels,
        'channel_count': channelCount,
        'device_type': deviceType.name,
        'provisioned_at': DateTime.now().toIso8601String(),
        'provisioning_method': 'simplified_flow',
      };

      // Add optional fields if available
      if (deviceIp != null) metaJson['ip'] = deviceIp;
      if (hostname != null) metaJson['hostname'] = hostname;
      if (module != null) metaJson['module'] = module;
      if (version != null) metaJson['version'] = version;

      // Merge additional metadata
      if (additionalMeta != null) {
        metaJson.addAll(additionalMeta);
      }

      debugPrint('📝 Creating device in database...');

      // Create device using claim-based approach with retry logic
      // The claim_device RPC function handles existence checking internally
      String deviceId;
      try {
        deviceId = await NetworkConnectivityService.retryWithBackoff(
          () => _devicesRepo.createDeviceWithClaiming(
            topicBase: topicBase,
            macAddress: deviceMac,
            channels: channels,
            defaultName: deviceName,
            homeId: homeId,
            roomId: roomId,
            deviceType: deviceType.name,
            channelCount: channelCount,
            metaJson: metaJson,
          ),
          maxRetries: 3,
        );
      } catch (e) {
        // If device already exists, try to find it by topic or MAC
        if (e.toString().contains('unique_violation') ||
            e.toString().contains('already exists')) {
          debugPrint(
            '🔄 Device already exists, attempting to find existing device...',
          );

          // Check if device exists by topic or MAC
          final existingDevice = await _devicesRepo.checkDeviceExists(
            topicBase: topicBase,
            macAddress: deviceMac,
          );

          if (existingDevice['exists'] == true &&
              existingDevice['owned_by_current_user'] == true) {
            deviceId = existingDevice['device_id'];
            debugPrint('✅ Found existing device: $deviceId');
          } else if (existingDevice['exists'] == true) {
            throw Exception(
              'Device already exists but is owned by another user. '
              'Topic: ${existingDevice['topic_base']}, '
              'MAC: ${existingDevice['mac_address']}',
            );
          } else {
            // If not found, rethrow the original error
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Get the created device
      final deviceWithChannels = await _devicesRepo.getDeviceWithChannels(
        deviceId,
      );
      if (deviceWithChannels == null) {
        throw Exception('Failed to retrieve created device');
      }

      // Convert to Device object for backward compatibility
      final device = Device(
        id: deviceWithChannels.id,
        homeId: deviceWithChannels.homeId,
        roomId: deviceWithChannels.roomId,
        displayName: deviceWithChannels.displayName,
        nameIsCustom: deviceWithChannels.nameIsCustom,
        deviceType: DeviceType.values.byName(deviceWithChannels.deviceType),
        channels: deviceWithChannels.channels,
        topicBase: deviceWithChannels.topicBase,
        macAddress: deviceWithChannels.macAddress,
        ownerUserId: deviceWithChannels.ownerUserId,
        matterType: deviceWithChannels.matterType,
        metaJson: deviceWithChannels.metaJson,
        createdAt: deviceWithChannels.createdAt,
        updatedAt: deviceWithChannels.updatedAt,
      );

      debugPrint('✅ Device created successfully: ${device.id}');

      // If it's a shutter device, seed the shutter_states table
      if (deviceType == DeviceType.shutter) {
        await _seedShutterState(device.id, additionalMeta);
      }

      // Register device with MQTT service for immediate control
      await _registerDeviceWithMqtt(device);

      return device;
    } catch (e) {
      debugPrint('❌ Device creation failed: $e');
      debugPrint('❌ ERROR TYPE: ${e.runtimeType}');
      debugPrint('❌ STACK TRACE: ${StackTrace.current}');
      throw Exception('Failed to create device from provisioning: $e');
    }
  }

  /// Create device from TasmotaDeviceInfo (legacy support)
  Future<Device> createDeviceFromTasmotaInfo({
    required String homeId,
    String? roomId,
    required String deviceName,
    required TasmotaDeviceInfo deviceInfo,
  }) async {
    return createDeviceFromProvisioning(
      homeId: homeId,
      roomId: roomId,
      deviceName: deviceName,
      deviceMac: deviceInfo.mac,
      mqttTopic: deviceInfo.topicBase,
      channels: deviceInfo.channels,
      deviceIp: deviceInfo.ip,
      hostname: deviceInfo.hostname,
      module: deviceInfo.module,
      version: deviceInfo.version,
      additionalMeta: {
        'sensors': deviceInfo.sensors,
        'fullTopic': deviceInfo.fullTopic,
        'status': deviceInfo.status,
      },
    );
  }

  /// Seed shutter_states table for a new shutter device
  Future<void> _seedShutterState(
    String deviceId,
    Map<String, dynamic>? additionalMeta,
  ) async {
    try {
      debugPrint('🪟 Seeding shutter_states for device: $deviceId');

      // Parse initial position from STATUS 8 if available
      int? initialPosition;
      int? initialDirection;
      int? initialTarget;

      if (additionalMeta != null && additionalMeta.containsKey('status')) {
        final status = additionalMeta['status'] as Map<String, dynamic>?;
        if (status != null) {
          // Try to extract Shutter1 data
          final statusSNS = status['StatusSNS'] as Map<String, dynamic>?;
          if (statusSNS != null && statusSNS.containsKey('Shutter1')) {
            final shutter1 = statusSNS['Shutter1'];
            if (shutter1 is Map<String, dynamic>) {
              initialPosition = shutter1['Position'] as int?;
              initialDirection = shutter1['Direction'] as int?;
              initialTarget = shutter1['Target'] as int?;
            } else if (shutter1 is int) {
              initialPosition = shutter1;
            }
          } else if (status.containsKey('Shutter1')) {
            final shutter1 = status['Shutter1'];
            if (shutter1 is Map<String, dynamic>) {
              initialPosition = shutter1['Position'] as int?;
              initialDirection = shutter1['Direction'] as int?;
              initialTarget = shutter1['Target'] as int?;
            } else if (shutter1 is int) {
              initialPosition = shutter1;
            }
          }
        }
      }

      // Call upsert_shutter_state function
      await Supabase.instance.client.rpc(
        'upsert_shutter_state',
        params: {
          'p_device_id': deviceId,
          'p_position': initialPosition ?? 0,
          'p_direction': initialDirection ?? 0,
          'p_target': initialTarget ?? 0,
          'p_tilt': null,
        },
      );

      debugPrint('✅ Shutter state seeded successfully');
    } catch (e) {
      // Log error but don't fail device creation
      debugPrint('⚠️ Warning: Failed to seed shutter state: $e');
    }
  }

  /// Register device with MQTT service for immediate control
  Future<void> _registerDeviceWithMqtt(Device device) async {
    try {
      // Ensure MQTT service is connected
      if (_mqttService.connectionState != MqttConnectionState.connected) {
        // Try to connect if not already connected
        final connected = await _mqttService.connect();
        if (!connected) {
          throw Exception('Failed to connect to MQTT broker');
        }
      }

      // Create a device with the topic base for MQTT registration
      final mqttDevice = device.copyWith(
        tasmotaTopicBase: device.deviceTopicBase,
      );

      // Register device for MQTT control
      await _mqttService.registerDevice(mqttDevice);

      // Request initial device state
      await _mqttService.requestDeviceStatus(device.id);
    } catch (e) {
      // Log error but don't fail device creation
      debugPrint('Warning: Failed to register device with MQTT: $e');
    }
  }

  /// Determine device type based on channels, module info, and STATUS 8 data
  DeviceType _determineDeviceType(
    int channels,
    String? module,
    Map<String, dynamic>? additionalMeta,
  ) {
    // First check if STATUS 8 data indicates a shutter device
    if (additionalMeta != null && additionalMeta.containsKey('status')) {
      final status = additionalMeta['status'] as Map<String, dynamic>?;
      if (status != null && ChannelDetectionUtils.isShutterDevice(status)) {
        debugPrint('🪟 Detected shutter device from STATUS 8');
        return DeviceType.shutter;
      }
    }

    // Default to relay for hbot devices
    if (module == null) return DeviceType.relay;

    final moduleStr = module.toLowerCase();

    // Check for specific device types
    if (moduleStr.contains('dimmer')) {
      return DeviceType.dimmer;
    } else if (moduleStr.contains('shutter') || moduleStr.contains('blind')) {
      return DeviceType.shutter;
    } else if (moduleStr.contains('sensor') || moduleStr.contains('temp')) {
      return DeviceType.sensor;
    } else if (channels > 0) {
      // Multi-channel devices are typically relays
      return DeviceType.relay;
    }

    return DeviceType.other;
  }

  /// Generate device name suggestion based on room and device type
  String generateDeviceName({
    String? roomName,
    DeviceType? deviceType,
    int? channels,
  }) {
    final buffer = StringBuffer();

    // Add room prefix if available
    if (roomName != null && roomName.isNotEmpty) {
      buffer.write('$roomName ');
    }

    // Add device type
    switch (deviceType) {
      case DeviceType.relay:
        if (channels != null && channels > 1) {
          buffer.write('Switch ($channels CH)');
        } else {
          buffer.write('Switch');
        }
        break;
      case DeviceType.dimmer:
        buffer.write('Dimmer');
        break;
      case DeviceType.shutter:
        buffer.write('Shutter');
        break;
      case DeviceType.sensor:
        buffer.write('Sensor');
        break;
      default:
        buffer.write('Device');
    }

    return buffer.toString().trim();
  }

  /// Validate MQTT topic format
  bool isValidMqttTopic(String topic) {
    if (topic.isEmpty) return false;

    // Basic MQTT topic validation
    if (topic.contains('+') || topic.contains('#')) return false;
    if (topic.startsWith('/') || topic.endsWith('/')) return false;
    if (topic.contains('//')) return false;

    return true;
  }

  /// Extract MAC address from various formats
  String? extractMacFromString(String input) {
    // Common MAC address patterns
    final patterns = [
      RegExp(
        r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})',
      ), // XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX
      RegExp(r'([0-9A-Fa-f]{2}){6}'), // XXXXXXXXXXXX
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  /// Parse channel count from device status with enhanced detection
  int parseChannelCount(Map<String, dynamic>? status) {
    if (status == null) return 8; // Default for hbot devices

    // Use the enhanced channel detection utility
    return ChannelDetectionUtils.detectChannelCount(status);
  }

  /// Create multiple devices from batch provisioning
  Future<List<Device>> createDevicesFromBatch({
    required String homeId,
    String? roomId,
    required List<Map<String, dynamic>> deviceDataList,
  }) async {
    final devices = <Device>[];

    for (int i = 0; i < deviceDataList.length; i++) {
      final deviceData = deviceDataList[i];

      try {
        final device = await createDeviceFromProvisioning(
          homeId: homeId,
          roomId: roomId,
          deviceName: deviceData['name'] ?? 'Device ${i + 1}',
          deviceMac: deviceData['mac'] ?? '',
          mqttTopic: deviceData['topic'] ?? '',
          channels: deviceData['channels'] ?? 8,
          deviceIp: deviceData['ip'],
          hostname: deviceData['hostname'],
          module: deviceData['module'],
          version: deviceData['version'],
          additionalMeta: deviceData['meta'],
        );

        devices.add(device);
      } catch (e) {
        debugPrint('Failed to create device ${i + 1}: $e');
        // Continue with other devices
      }
    }

    return devices;
  }

  /// Update device MQTT configuration
  Future<void> updateDeviceMqttConfig({
    required String deviceId,
    String? newTopic,
    int? newChannels,
  }) async {
    try {
      // Get current device
      final devices = await _smartHomeService.getDevicesForCurrentHome();
      final device = devices.firstWhere((d) => d.id == deviceId);

      // Update metadata
      final currentMeta = Map<String, dynamic>.from(device.metaJson ?? {});

      if (newTopic != null) {
        currentMeta['mqtt_topic'] = newTopic;
        currentMeta['mqtt_cmd_base'] = 'cmnd/$newTopic/';
        currentMeta['mqtt_stat_base'] = 'stat/$newTopic/';
        currentMeta['mqtt_tele_base'] = 'tele/$newTopic/';
      }

      if (newChannels != null) {
        currentMeta['channels'] = newChannels;
      }

      // Update device in database
      // Note: This would require adding an update method to SmartHomeService
      // For now, we'll just re-register with MQTT

      // Re-register with MQTT service
      final updatedDevice = device.copyWith(
        tasmotaTopicBase: newTopic ?? device.tasmotaTopicBase,
        channels: newChannels ?? device.channels,
        metaJson: currentMeta,
      );

      await _mqttService.registerDevice(updatedDevice);
    } catch (e) {
      throw Exception('Failed to update device MQTT config: $e');
    }
  }
}

/// Extension to add copyWith method to Device
extension DeviceCopyWith on Device {
  Device copyWith({
    String? id,
    String? homeId,
    String? roomId,
    String? name,
    DeviceType? deviceType,
    int? channels,
    String? tasmotaTopicBase,
    String? matterType,
    Map<String, dynamic>? metaJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      channels: channels ?? this.channels,
      tasmotaTopicBase: tasmotaTopicBase ?? this.tasmotaTopicBase,
      matterType: matterType ?? this.matterType,
      metaJson: metaJson ?? this.metaJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
