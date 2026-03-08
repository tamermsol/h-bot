import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/device_channel.dart';

/// Custom exception for device claim operations
class DeviceClaimException implements Exception {
  final String message;
  final String code;

  const DeviceClaimException(this.message, this.code);

  @override
  String toString() => message;
}

/// Repository for device management operations including claiming, renaming, and channel management
class DeviceManagementRepo {
  /// Claim a device for the current user
  /// This enforces device uniqueness and handles ownership
  Future<String> claimDevice({
    required String topicBase,
    String? macAddress,
    required int channels,
    required String defaultName,
    required String homeId,
    String? roomId,
    String deviceType = 'relay',
    int? channelCount,
    String? matterType,
    Map<String, dynamic>? metaJson,
  }) async {
    try {
      debugPrint(
        '🔄 Claiming device: $topicBase (type: $deviceType, channels: $channels, channel_count: $channelCount)',
      );

      final response = await supabase.rpc(
        'claim_device',
        params: {
          'p_topic_base': topicBase,
          'p_mac': macAddress,
          'p_channels': channels,
          'p_default_name': defaultName,
          'p_home_id': homeId,
          'p_room_id': roomId,
          'p_device_type': deviceType,
          'p_channel_count': channelCount,
        },
      );

      if (response == null) {
        throw DeviceClaimException('No response from server', 'UNKNOWN_ERROR');
      }

      debugPrint('✅ Device claimed successfully: $response');
      return response as String;
    } catch (e) {
      debugPrint('❌ Device claim failed: $e');

      // Handle specific PostgreSQL errors
      if (e is PostgrestException) {
        return _handlePostgrestException(e);
      }

      // Handle known error messages
      if (e.toString().contains('already linked to another account')) {
        throw DeviceClaimException(
          'This device is already linked to another account. Please reset the device or contact support.',
          'DEVICE_ALREADY_OWNED',
        );
      }

      if (e.toString().contains('not authenticated')) {
        throw DeviceClaimException(
          'Authentication required. Please log in and try again.',
          'NOT_AUTHENTICATED',
        );
      }

      throw DeviceClaimException('Failed to claim device: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Handle PostgrestException with specific error codes
  String _handlePostgrestException(PostgrestException e) {
    debugPrint('PostgrestException: code=${e.code}, message=${e.message}');

    switch (e.code) {
      case '42501': // insufficient_privilege
        throw DeviceClaimException(
          'Permission denied. Check your Supabase policies.',
          'PERMISSION_DENIED',
        );
      case '23505': // unique_violation
        throw DeviceClaimException(
          'Device already exists. This may indicate a duplicate device.',
          'UNIQUE_VIOLATION',
        );
      case '23503': // foreign_key_violation
        throw DeviceClaimException(
          'Invalid home or room ID provided.',
          'INVALID_REFERENCE',
        );
      case '23514': // check_violation
        throw DeviceClaimException(
          'Invalid device parameters provided.',
          'INVALID_PARAMETERS',
        );
      default:
        throw DeviceClaimException(
          'Database error: ${e.message}',
          'DATABASE_ERROR',
        );
    }
  }

  /// Rename a device
  Future<void> renameDevice({
    required String deviceId,
    required String newName,
  }) async {
    try {
      debugPrint('🔄 Renaming device: $deviceId to "$newName"');

      await supabase.rpc(
        'rename_device',
        params: {'p_device_id': deviceId, 'p_name': newName.trim()},
      );

      debugPrint('✅ Device renamed successfully');
    } catch (e) {
      debugPrint('❌ Device rename failed: $e');

      if (e.toString().contains('Device not found') ||
          e.toString().contains('device not found')) {
        throw 'Device not found or access denied';
      }
      if (e.toString().contains('cannot be empty')) {
        throw 'Device name cannot be empty';
      }
      if (e.toString().contains('not authenticated')) {
        throw 'Authentication required. Please log in and try again.';
      }
      throw 'Failed to rename device: $e';
    }
  }

  /// Rename a device channel
  Future<void> renameChannel({
    required String deviceId,
    required int channelNo,
    required String newLabel,
  }) async {
    try {
      debugPrint('🔄 Renaming channel: $deviceId/$channelNo to "$newLabel"');

      await supabase.rpc(
        'rename_channel',
        params: {
          'p_device_id': deviceId,
          'p_channel_no': channelNo,
          'p_label': newLabel.trim(),
        },
      );

      debugPrint('✅ Channel renamed successfully');
    } catch (e) {
      debugPrint('❌ Channel rename failed: $e');

      if (e.toString().contains('Device not found') ||
          e.toString().contains('device not found')) {
        throw 'Device not found or access denied';
      }
      if (e.toString().contains('cannot be empty')) {
        throw 'Channel label cannot be empty';
      }
      if (e.toString().contains('Invalid channel number')) {
        throw 'Invalid channel number: $channelNo';
      }
      if (e.toString().contains('not authenticated')) {
        throw 'Authentication required. Please log in and try again.';
      }
      throw 'Failed to rename channel: $e';
    }
  }

  /// Update channel type (light or switch)
  Future<void> updateChannelType({
    required String deviceId,
    required int channelNo,
    required String channelType,
  }) async {
    try {
      debugPrint(
        '🔄 Updating channel type: $deviceId/$channelNo to "$channelType"',
      );

      if (channelType != 'light' && channelType != 'switch') {
        throw 'Invalid channel type: must be light or switch';
      }

      await supabase.rpc(
        'update_channel_type',
        params: {
          'p_device_id': deviceId,
          'p_channel_no': channelNo,
          'p_channel_type': channelType,
        },
      );

      debugPrint('✅ Channel type updated successfully');
    } catch (e) {
      debugPrint('❌ Channel type update failed: $e');

      if (e.toString().contains('Device not found') ||
          e.toString().contains('device not found')) {
        throw 'Device not found or access denied';
      }
      if (e.toString().contains('invalid channel type')) {
        throw 'Invalid channel type: must be light or switch';
      }
      if (e.toString().contains('channel not found')) {
        throw 'Channel not found';
      }
      if (e.toString().contains('not authenticated')) {
        throw 'Authentication required. Please log in and try again.';
      }
      throw 'Failed to update channel type: $e';
    }
  }

  /// Get device with channel information
  Future<DeviceWithChannels?> getDeviceWithChannels(String deviceId) async {
    try {
      debugPrint('🔍 Getting device with channels: $deviceId');

      // Use the view directly to ensure we get the latest channel_type data
      final response = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('id', deviceId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No device found for ID: $deviceId');
        return null;
      }

      debugPrint('📦 Device data received: $response');
      debugPrint('📋 Channel labels: ${response['channel_labels']}');

      final device = DeviceWithChannels.fromJson(response);
      debugPrint('✅ Device with channels parsed successfully');

      return device;
    } catch (e) {
      debugPrint('❌ Failed to get device with channels: $e');
      throw 'Failed to get device with channels: $e';
    }
  }

  /// Get all devices for the current user with channel information
  Future<List<DeviceWithChannels>> getUserDevicesWithChannels({
    String? homeId,
  }) async {
    try {
      // Use the devices_with_channels view for consistency
      PostgrestFilterBuilder query = supabase
          .from('devices_with_channels')
          .select('*');

      if (homeId != null) {
        query = query.eq('home_id', homeId);
      }

      final response = await query.order('inserted_at', ascending: false);

      if (response == null) {
        return [];
      }

      final devices = <DeviceWithChannels>[];
      for (final deviceData in response as List) {
        devices.add(DeviceWithChannels.fromJson(deviceData));
      }

      return devices;
    } catch (e) {
      // Fallback to direct table query if RPC fails
      try {
        final response = await supabase
            .from('devices_with_channels')
            .select('*')
            .eq('owner_user_id', supabase.auth.currentUser!.id)
            .order('inserted_at', ascending: false);

        final devices = <DeviceWithChannels>[];
        for (final deviceData in response) {
          devices.add(DeviceWithChannels.fromJson(deviceData));
        }

        return devices;
      } catch (fallbackError) {
        throw 'Failed to get user devices: $e (fallback: $fallbackError)';
      }
    }
  }

  /// Get device channels for a specific device
  Future<List<DeviceChannel>> getDeviceChannels(String deviceId) async {
    try {
      final response = await supabase
          .from('device_channels')
          .select('*')
          .eq('device_id', deviceId)
          .order('channel_no');

      final channels = <DeviceChannel>[];
      for (final channelData in response) {
        channels.add(DeviceChannel.fromJson(channelData));
      }

      return channels;
    } catch (e) {
      throw 'Failed to get device channels: $e';
    }
  }

  /// Check if a device with the given topic base or MAC address already exists
  Future<Map<String, dynamic>> checkDeviceExists({
    String? topicBase,
    String? macAddress,
  }) async {
    try {
      debugPrint(
        '🔍 Checking device existence: topic=$topicBase, mac=$macAddress',
      );

      if (topicBase == null && macAddress == null) {
        throw 'Either topic base or MAC address must be provided';
      }

      // Normalize inputs to match database generated columns
      final normalizedTopic = topicBase?.toLowerCase();
      final normalizedMac = macAddress?.toUpperCase().replaceAll(
        RegExp(r'[^A-F0-9]'),
        '',
      );

      PostgrestFilterBuilder query = supabase
          .from('devices')
          .select('id, owner_user_id, display_name, topic_base, mac_address');

      // Build the OR condition using proper Supabase syntax
      if (normalizedTopic != null &&
          normalizedMac != null &&
          normalizedMac.isNotEmpty) {
        // Check both topic_key and mac_key using the generated columns
        query = query.or(
          'topic_key.eq.$normalizedTopic,mac_key.eq.$normalizedMac',
        );
      } else if (normalizedTopic != null) {
        // Check only topic_key
        query = query.eq('topic_key', normalizedTopic);
      } else if (normalizedMac != null && normalizedMac.isNotEmpty) {
        // Check only mac_key
        query = query.eq('mac_key', normalizedMac);
      } else {
        return {'exists': false, 'owned_by_current_user': false};
      }

      final response = await query.maybeSingle();

      if (response == null) {
        debugPrint('✅ Device does not exist');
        return {'exists': false, 'owned_by_current_user': false};
      }

      final currentUserId = supabase.auth.currentUser?.id;
      final isOwnedByCurrentUser = response['owner_user_id'] == currentUserId;

      debugPrint(
        '📱 Device exists: owned_by_current_user=$isOwnedByCurrentUser',
      );

      return {
        'exists': true,
        'owned_by_current_user': isOwnedByCurrentUser,
        'device_id': response['id'],
        'device_name': response['display_name'],
        'topic_base': response['topic_base'],
        'mac_address': response['mac_address'],
      };
    } catch (e) {
      debugPrint('❌ Failed to check device existence: $e');
      throw 'Failed to check device existence: $e';
    }
  }

  /// Reset device name to default (remove custom name)
  Future<void> resetDeviceNameToDefault(String deviceId) async {
    try {
      await supabase
          .from('devices_new')
          .update({
            'name_is_custom': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', deviceId)
          .eq('owner_user_id', supabase.auth.currentUser!.id);
    } catch (e) {
      throw 'Failed to reset device name: $e';
    }
  }

  /// Reset channel label to default (remove custom label)
  Future<void> resetChannelLabelToDefault({
    required String deviceId,
    required int channelNo,
  }) async {
    try {
      await supabase
          .from('device_channels')
          .update({
            'label': 'Channel $channelNo',
            'label_is_custom': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_id', deviceId)
          .eq('channel_no', channelNo);
    } catch (e) {
      throw 'Failed to reset channel label: $e';
    }
  }

  /// Update device placement (home and room)
  Future<void> updateDevicePlacement({
    required String deviceId,
    String? homeId,
    String? roomId,
  }) async {
    try {
      await supabase
          .from('devices_new')
          .update({
            'home_id': homeId,
            'room_id': roomId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', deviceId)
          .eq('owner_user_id', supabase.auth.currentUser!.id);
    } catch (e) {
      throw 'Failed to update device placement: $e';
    }
  }
}
