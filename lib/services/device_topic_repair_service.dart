import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/tasmota_device_info.dart';
import '../repos/devices_repo.dart';

/// Service to repair devices with invalid MQTT topics
class DeviceTopicRepairService {
  final DevicesRepo _devicesRepo = DevicesRepo();

  /// Check if a device has an invalid MQTT topic
  bool hasInvalidTopic(Device device) {
    if (device.tasmotaTopicBase == null) return true;

    final topic = device.tasmotaTopicBase!;

    // Check for common invalid patterns
    if (topic.contains('NKNOWN') ||
        topic.contains('UNKNOWN') ||
        topic.isEmpty ||
        topic == 'hbot_' ||
        !topic.startsWith('hbot_')) {
      return true;
    }

    // Check if topic suffix is valid (should be 6 hex characters)
    if (topic.length < 11) return true; // 'hbot_' + 6 chars = 11

    final suffix = topic.substring(5); // Remove 'hbot_' prefix
    if (suffix.length != 6) return true;

    // Check if suffix contains only valid hex characters
    final hexPattern = RegExp(r'^[0-9A-Fa-f]+$');
    return !hexPattern.hasMatch(suffix);
  }

  /// Attempt to repair a device's MQTT topic using metadata
  Future<String?> repairDeviceTopic(Device device) async {
    debugPrint('🔧 Attempting to repair MQTT topic for device: ${device.name}');

    // Try to extract MAC from metadata
    String? mac = _extractMacFromMetadata(device);

    if (mac != null) {
      final newTopic = TasmotaDeviceInfo.generateTopicFromMac(mac);
      debugPrint('✅ Generated new topic from MAC: $newTopic');
      return newTopic;
    }

    // Try to extract from device name if it contains MAC-like pattern
    mac = _extractMacFromName(device.deviceName);
    if (mac != null) {
      final newTopic = TasmotaDeviceInfo.generateTopicFromMac(mac);
      debugPrint('✅ Generated new topic from name: $newTopic');
      return newTopic;
    }

    debugPrint('❌ Could not repair topic for device: ${device.name}');
    return null;
  }

  /// Extract MAC address from device metadata
  String? _extractMacFromMetadata(Device device) {
    if (device.metaJson == null) return null;

    final meta = device.metaJson!;

    // Check common MAC field names
    final macFields = ['mac', 'MAC', 'macAddress', 'mac_address', 'device_mac'];

    for (final field in macFields) {
      if (meta.containsKey(field)) {
        final macValue = meta[field];
        if (macValue is String && _isValidMac(macValue)) {
          return macValue;
        }
      }
    }

    return null;
  }

  /// Extract MAC-like pattern from device name
  String? _extractMacFromName(String name) {
    // Look for MAC-like patterns in the name
    final macPattern = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
    final match = macPattern.firstMatch(name);

    if (match != null) {
      return match.group(0);
    }

    // Look for hex patterns that might be MAC suffixes
    final hexPattern = RegExp(r'[0-9A-Fa-f]{6,12}');
    final hexMatch = hexPattern.firstMatch(name);

    if (hexMatch != null) {
      final hex = hexMatch.group(0)!;
      if (hex.length >= 6) {
        // Format as MAC address (take last 12 chars and format)
        final macHex = hex.substring(hex.length - 12).toUpperCase();
        return '${macHex.substring(0, 2)}:${macHex.substring(2, 4)}:${macHex.substring(4, 6)}:${macHex.substring(6, 8)}:${macHex.substring(8, 10)}:${macHex.substring(10, 12)}';
      }
    }

    return null;
  }

  /// Validate MAC address format
  bool _isValidMac(String mac) {
    final macPattern = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$');
    return macPattern.hasMatch(mac);
  }

  /// Update device with repaired topic
  Future<bool> updateDeviceTopic(Device device, String newTopic) async {
    try {
      debugPrint('🔄 Updating device ${device.name} with new topic: $newTopic');

      await _devicesRepo.updateDevice(device.id, tasmotaTopicBase: newTopic);

      debugPrint('✅ Successfully updated device topic');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update device topic: $e');
      return false;
    }
  }

  /// Repair all devices with invalid topics in a home
  Future<List<Device>> repairAllDevicesInHome(String homeId) async {
    debugPrint('🏠 Repairing all devices in home: $homeId');

    final repairedDevices = <Device>[];

    try {
      final devices = await _devicesRepo.listDevicesByHome(homeId);

      for (final device in devices) {
        if (hasInvalidTopic(device)) {
          debugPrint(
            '🔧 Found device with invalid topic: ${device.name} (${device.tasmotaTopicBase})',
          );

          final newTopic = await repairDeviceTopic(device);
          if (newTopic != null) {
            final success = await updateDeviceTopic(device, newTopic);
            if (success) {
              final updatedDevice = device.copyWith(tasmotaTopicBase: newTopic);
              repairedDevices.add(updatedDevice);
            }
          }
        }
      }

      debugPrint('✅ Repaired ${repairedDevices.length} devices');
      return repairedDevices;
    } catch (e) {
      debugPrint('❌ Failed to repair devices: $e');
      return [];
    }
  }

  /// Generate a fallback topic based on device ID
  String generateFallbackTopic(Device device) {
    // Use last 6 characters of device ID as fallback
    final deviceIdSuffix = device.id.replaceAll('-', '').toUpperCase();
    final suffix = deviceIdSuffix.substring(deviceIdSuffix.length - 6);
    return 'hbot_$suffix';
  }

  /// Repair device with fallback topic if MAC extraction fails
  Future<bool> repairDeviceWithFallback(Device device) async {
    debugPrint('🔧 Repairing device with fallback topic: ${device.name}');

    String? newTopic = await repairDeviceTopic(device);

    if (newTopic == null) {
      // Use fallback topic generation
      newTopic = generateFallbackTopic(device);
      debugPrint('⚠️ Using fallback topic: $newTopic');
    }

    return await updateDeviceTopic(device, newTopic);
  }

  /// Get repair status for a device
  Map<String, dynamic> getDeviceRepairStatus(Device device) {
    final hasInvalid = hasInvalidTopic(device);
    final canRepair =
        device.metaJson != null &&
        (_extractMacFromMetadata(device) != null ||
            _extractMacFromName(device.deviceName) != null);

    return {
      'hasInvalidTopic': hasInvalid,
      'canRepair': canRepair,
      'currentTopic': device.tasmotaTopicBase,
      'suggestedTopic': hasInvalid
          ? (canRepair ? 'Can be repaired' : 'Needs manual fix')
          : null,
    };
  }
}
