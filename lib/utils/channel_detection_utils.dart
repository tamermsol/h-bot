import 'package:flutter/foundation.dart';

/// Utility class for detecting the number of channels on Tasmota devices
/// Supports 2, 4, and 8 channel configurations
class ChannelDetectionUtils {
  /// Valid channel counts for hbot devices
  static const List<int> validChannelCounts = [2, 4, 8];

  /// Detect the number of channels from device status response
  /// Uses multiple detection methods for accuracy
  static int detectChannelCount(Map<String, dynamic> status) {
    debugPrint('🔍 Detecting channel count from status: ${status.keys}');

    // PRIORITY: Check if this is a shutter device first
    // Shutters should always be treated as 1-channel devices
    if (isShutterDevice(status)) {
      debugPrint('🪟 Detected SHUTTER device - returning 1 channel');
      return 1;
    }

    // Method 1: Check Power field in Status section (most reliable for basic status)
    final channelsFromStatusPower = _detectFromStatusPower(status);
    if (channelsFromStatusPower > 0) {
      final validatedChannels = _validateChannelCount(channelsFromStatusPower);
      debugPrint(
        '✅ Detected $validatedChannels channels from Status.Power field',
      );
      return validatedChannels;
    }

    // Method 2: Check POWER states in StatusSTS (fallback)
    final channelsFromPower = _detectFromPowerStates(status);
    if (channelsFromPower > 0) {
      final validatedChannels = _validateChannelCount(channelsFromPower);
      debugPrint('✅ Detected $validatedChannels channels from POWER states');
      return validatedChannels;
    }

    // Method 2: Check FriendlyName array length
    final channelsFromFriendlyNames = _detectFromFriendlyNames(status);
    if (channelsFromFriendlyNames > 0) {
      final validatedChannels = _validateChannelCount(
        channelsFromFriendlyNames,
      );
      debugPrint(
        '✅ Detected $validatedChannels channels from FriendlyName array',
      );
      return validatedChannels;
    }

    // Method 3: Check GPIO configuration for relay pins
    final channelsFromGPIO = _detectFromGPIOConfig(status);
    if (channelsFromGPIO > 0) {
      final validatedChannels = _validateChannelCount(channelsFromGPIO);
      debugPrint(
        '✅ Detected $validatedChannels channels from GPIO configuration',
      );
      return validatedChannels;
    }

    // Method 4: Check Module type for known configurations
    final channelsFromModule = _detectFromModuleType(status);
    if (channelsFromModule > 0) {
      final validatedChannels = _validateChannelCount(channelsFromModule);
      debugPrint('✅ Detected $validatedChannels channels from Module type');
      return validatedChannels;
    }

    // Default fallback - assume 8 channels for hbot devices
    debugPrint('⚠️ Could not detect channel count, defaulting to 8 channels');
    return 8;
  }

  /// Detect if device is a shutter/blind device
  /// Checks STATUS 8 (StatusSNS) for Shutter1 field or StatusSHT
  static bool isShutterDevice(Map<String, dynamic> status) {
    // Check StatusSNS for Shutter1
    final statusSNS = status['StatusSNS'] as Map<String, dynamic>?;
    if (statusSNS != null) {
      if (statusSNS.containsKey('Shutter1') ||
          statusSNS.containsKey('StatusSHT')) {
        debugPrint('🪟 Found Shutter1 or StatusSHT in StatusSNS');
        return true;
      }
    }

    // Check root level for Shutter1 (from RESULT messages)
    if (status.containsKey('Shutter1')) {
      debugPrint('🪟 Found Shutter1 in root level');
      return true;
    }

    // Check SetOption80 (shutter mode enabled)
    final statusSTO = status['StatusSTO'] as Map<String, dynamic>?;
    if (statusSTO != null && statusSTO['SetOption80'] == 1) {
      debugPrint('🪟 SetOption80 enabled - shutter mode active');
      return true;
    }

    return false;
  }

  /// Detect channels from Power field in Status section (for basic status command)
  static int _detectFromStatusPower(Map<String, dynamic> status) {
    final statusSection = status['Status'] as Map<String, dynamic>?;
    if (statusSection == null) return 0;

    final powerField = statusSection['Power'];
    if (powerField == null) return 0;

    final powerString = powerField.toString();
    debugPrint('🔍 Analyzing Power field: $powerString');

    // Power field contains binary representation of channel states
    // e.g., "00000000" for 8 channels all OFF, "11" for 2 channels
    // The length indicates the number of channels
    if (powerString.isNotEmpty) {
      final channelCount = powerString.length;
      debugPrint('📊 Power field length indicates $channelCount channels');
      return channelCount;
    }

    return 0;
  }

  /// Detect channels from POWER state keys in StatusSTS
  static int _detectFromPowerStates(Map<String, dynamic> status) {
    final statusSTS = status['StatusSTS'] as Map<String, dynamic>?;
    if (statusSTS == null) return 0;

    int maxChannel = 0;

    // Check for POWER1, POWER2, etc.
    for (int i = 1; i <= 8; i++) {
      if (statusSTS.containsKey('POWER$i')) {
        maxChannel = i;
      }
    }

    // Handle single POWER key (single channel device)
    if (maxChannel == 0 && statusSTS.containsKey('POWER')) {
      maxChannel = 1;
    }

    return maxChannel;
  }

  /// Detect channels from FriendlyName array
  static int _detectFromFriendlyNames(Map<String, dynamic> status) {
    final friendlyNames = status['FriendlyName'];
    if (friendlyNames is List) {
      // Count non-empty friendly names
      final nonEmptyNames = friendlyNames
          .where((name) => name != null && name.toString().trim().isNotEmpty)
          .length;
      return nonEmptyNames;
    }
    return 0;
  }

  /// Detect channels from GPIO configuration
  static int _detectFromGPIOConfig(Map<String, dynamic> status) {
    final statusGPIO = status['StatusGPIO'] as Map<String, dynamic>?;
    if (statusGPIO == null) return 0;

    int relayCount = 0;
    statusGPIO.forEach((key, value) {
      final valueStr = value.toString().toLowerCase();
      if (valueStr.contains('relay') || valueStr.contains('rel_')) {
        relayCount++;
      }
    });

    return relayCount;
  }

  /// Detect channels from Module type
  static int _detectFromModuleType(Map<String, dynamic> status) {
    // Check for Module in both root level and Status section
    String module = '';
    if (status.containsKey('Module')) {
      module = status['Module']?.toString().toLowerCase() ?? '';
    } else if (status.containsKey('Status') && status['Status'] is Map) {
      final statusSection = status['Status'] as Map<String, dynamic>;
      module = statusSection['Module']?.toString().toLowerCase() ?? '';
    }

    // Known module patterns for different channel counts
    if (module.contains('2ch') ||
        module.contains('2 ch') ||
        module.contains('dual')) {
      return 2;
    }
    if (module.contains('4ch') ||
        module.contains('4 ch') ||
        module.contains('quad')) {
      return 4;
    }
    if (module.contains('8ch') ||
        module.contains('8 ch') ||
        module.contains('octo')) {
      return 8;
    }

    return 0;
  }

  /// Validate and normalize channel count to supported values (2, 4, 8)
  static int _validateChannelCount(int detectedChannels) {
    if (detectedChannels <= 0) return 8; // Default fallback

    // If detected count is already valid, return it
    if (validChannelCounts.contains(detectedChannels)) {
      return detectedChannels;
    }

    // Round up to the nearest valid channel count
    if (detectedChannels <= 2) return 2;
    if (detectedChannels <= 4) return 4;
    return 8; // For 5+ channels, assume 8-channel device
  }

  /// Get display name for channel count
  static String getChannelCountDisplayName(int channels) {
    switch (channels) {
      case 2:
        return '2-Channel Device';
      case 4:
        return '4-Channel Device';
      case 8:
        return '8-Channel Device';
      default:
        return '$channels-Channel Device';
    }
  }

  /// Check if a channel count is valid for hbot devices
  /// Returns true for null (shutters) or valid channel counts
  static bool isValidChannelCount(int? channels) {
    // Shutters have null channels - this is valid
    if (channels == null) return true;

    return validChannelCounts.contains(channels);
  }

  /// Get the optimal grid layout for channel controls
  /// IMPORTANT: Do NOT call this for shutters (channels == null)
  /// Shutters use a different UI (Close/Stop/Open buttons, not channel grid)
  static Map<String, int> getOptimalGridLayout(int? channels) {
    // Guard: if channels is null or <= 0, return safe default
    if (channels == null || channels <= 0) {
      debugPrint(
        '⚠️ getOptimalGridLayout called with null/0 channels - returning safe default',
      );
      return {'columns': 1, 'rows': 1};
    }

    switch (channels) {
      case 2:
        return {'columns': 2, 'rows': 1}; // 2x1 grid
      case 4:
        return {'columns': 2, 'rows': 2}; // 2x2 grid
      case 8:
        return {'columns': 2, 'rows': 4}; // 2x4 grid
      default:
        // For other counts, calculate optimal layout
        final columns = channels <= 4 ? channels : 2;
        // Guard against divide by zero
        if (columns <= 0) {
          return {'columns': 1, 'rows': 1};
        }
        final rows = (channels / columns).ceil();
        return {'columns': columns, 'rows': rows};
    }
  }
}
