import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../models/device.dart';
import '../models/device_state.dart';
import '../models/device_channel.dart';
import 'device_management_repo.dart';

class DevicesRepo {
  final DeviceManagementRepo _deviceManagementRepo = DeviceManagementRepo();

  /// List all devices in a home
  Future<List<Device>> listDevicesByHome(String homeId) async {
    try {
      final response = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('home_id', homeId)
          .order('name');

      return (response as List).map((json) => Device.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to load devices: $e';
    }
  }

  /// List devices shared with current user
  Future<List<Device>> listSharedDevices() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('listSharedDevices: No authenticated user');
        return [];
      }
      debugPrint('listSharedDevices: Fetching for user $userId');

      // Use RPC function (SECURITY DEFINER) to bypass view/RLS complexity
      final response = await supabase.rpc('get_shared_devices');
      debugPrint('listSharedDevices: RPC response type=${response.runtimeType}, value=$response');

      if (response == null) return [];

      final List<dynamic> data = response is List ? response : [response];
      final List<Device> devices = [];

      for (final json in data) {
        try {
          final map = json as Map<String, dynamic>;
          devices.add(Device.fromJson(map));
        } catch (parseErr) {
          debugPrint('listSharedDevices: Failed to parse device: $parseErr');
          debugPrint('listSharedDevices: Raw JSON: $json');
        }
      }

      debugPrint('listSharedDevices: Loaded ${devices.length} shared devices via RPC');
      return devices;
    } catch (e, stack) {
      debugPrint('listSharedDevices: FAILED: $e');
      debugPrint('listSharedDevices: Stack: $stack');
      return [];
    }
  }

  /// List all devices in a room
  Future<List<Device>> listDevicesByRoom(String roomId) async {
    try {
      final response = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('room_id', roomId)
          .order('name');

      return (response as List).map((json) => Device.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to load devices: $e';
    }
  }

  /// Get a single device by ID
  Future<Device?> getDevice(String deviceId) async {
    try {
      final response = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('id', deviceId)
          .maybeSingle();

      if (response == null) return null;
      return Device.fromJson(response);
    } catch (e) {
      debugPrint('Failed to get device: $e');
      return null;
    }
  }

  /// Get devices with their current state for a home
  Future<List<DeviceWithState>> listDevicesWithState(String homeId) async {
    try {
      // Use the devices_with_channels view which has correct column mappings
      final devices = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('home_id', homeId)
          .order('name');

      if (devices.isEmpty) return [];

      // Get device IDs
      final deviceIds = devices.map((d) => d['id'] as String).toList();

      // Get device states in batches (Supabase has query limits)
      final states = <Map<String, dynamic>>[];
      const batchSize = 100;

      for (int i = 0; i < deviceIds.length; i += batchSize) {
        final batch = deviceIds.skip(i).take(batchSize).toList();
        final batchStates = await supabase
            .from('device_state')
            .select('*')
            .inFilter('device_id', batch);
        states.addAll(List<Map<String, dynamic>>.from(batchStates));
      }

      // Create a map of device_id -> state
      final stateMap = <String, Map<String, dynamic>>{};
      for (final state in states) {
        stateMap[state['device_id']] = state;
      }

      // Combine devices with their states
      return devices.map((deviceJson) {
        final deviceId = deviceJson['id'] as String;
        final state = stateMap[deviceId];

        final combined = Map<String, dynamic>.from(deviceJson);
        if (state != null) {
          combined.addAll(state);
        }

        return DeviceWithState.fromJson(combined);
      }).toList();
    } catch (e) {
      throw 'Failed to load devices with state: $e';
    }
  }

  /// Create a new device
  Future<Device> createDevice(
    String homeId, {
    String? roomId,
    required String name,
    required DeviceType deviceType,
    required int channels,
    String? tasmotaTopicBase,
    String? matterType,
    Map<String, dynamic>? metaJson,
  }) async {
    try {
      final response = await supabase
          .from('devices')
          .insert({
            'home_id': homeId,
            'room_id': roomId,
            'name': name,
            'device_type': deviceType.name,
            'channels': channels,
            'tasmota_topic_base': tasmotaTopicBase,
            'matter_type': matterType,
            'meta_json': metaJson,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return Device.fromJson(response);
    } catch (e) {
      throw 'Failed to create device: $e';
    }
  }

  /// Update a device
  ///
  /// Note: To clear the room_id (set to null), pass an empty string for roomId.
  /// To leave room_id unchanged, don't pass the roomId parameter.
  Future<Device> updateDevice(
    String deviceId, {
    String? roomId,
    String? name,
    DeviceType? deviceType,
    int? channels,
    String? tasmotaTopicBase,
    String? matterType,
    Map<String, dynamic>? metaJson,
    bool clearRoom = false, // New parameter to explicitly clear room
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle room_id: if clearRoom is true, set to null; otherwise use roomId if provided
      if (clearRoom) {
        updates['room_id'] = null;
        debugPrint('🔧 DevicesRepo: Clearing room_id (setting to null)');
      } else if (roomId != null) {
        updates['room_id'] = roomId;
        debugPrint('🔧 DevicesRepo: Setting room_id to: $roomId');
      }

      if (name != null) updates['name'] = name;
      if (deviceType != null) updates['device_type'] = deviceType.name;
      if (channels != null) updates['channels'] = channels;
      if (tasmotaTopicBase != null) {
        updates['tasmota_topic_base'] = tasmotaTopicBase;
      }
      if (matterType != null) updates['matter_type'] = matterType;
      if (metaJson != null) updates['meta_json'] = metaJson;

      debugPrint('🔧 DevicesRepo: Updating device $deviceId with: $updates');

      // Update the device in the devices table
      await supabase.from('devices').update(updates).eq('id', deviceId);

      // Fetch the updated device from devices_with_channels view to ensure
      // all fields (including channels from joined tables) are present
      final response = await supabase
          .from('devices_with_channels')
          .select('*')
          .eq('id', deviceId)
          .single();

      debugPrint('🔧 DevicesRepo: Response from Supabase: $response');
      final roomIdValue = response['room_id'];
      debugPrint(
        '🔧 DevicesRepo: Response room_id type: ${roomIdValue?.runtimeType ?? 'null'}',
      );
      debugPrint('🔧 DevicesRepo: Response room_id value: $roomIdValue');

      return Device.fromJson(response);
    } catch (e) {
      debugPrint('❌ DevicesRepo: Error updating device: $e');
      debugPrint('❌ DevicesRepo: Error type: ${e.runtimeType}');
      throw 'Failed to update device: $e';
    }
  }

  /// Delete a device
  Future<void> deleteDevice(String deviceId) async {
    try {
      // First check if device exists
      final deviceCheck = await supabase
          .from('devices')
          .select('id')
          .eq('id', deviceId)
          .maybeSingle();

      if (deviceCheck == null) {
        throw 'Device not found. It may have already been deleted.';
      }

      // Delete device state first (foreign key constraint)
      await supabase.from('device_state').delete().eq('device_id', deviceId);

      // Delete device channels
      await supabase.from('device_channels').delete().eq('device_id', deviceId);

      // Delete the device
      final deleteResult = await supabase
          .from('devices')
          .delete()
          .eq('id', deviceId)
          .select();

      if (deleteResult.isEmpty) {
        throw 'Device could not be deleted. Please try again.';
      }
    } catch (e) {
      if (e.toString().contains('Device not found') ||
          e.toString().contains('Device could not be deleted')) {
        rethrow;
      }

      // Handle network and other errors
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        throw 'Network error. Please check your connection and try again.';
      }

      throw 'Failed to delete device: ${e.toString()}';
    }
  }

  /// Get device state
  Future<DeviceState?> getDeviceState(String deviceId) async {
    try {
      final response = await supabase
          .from('device_state')
          .select('*')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) return null;
      return DeviceState.fromJson(response);
    } catch (e) {
      throw 'Failed to get device state: $e';
    }
  }

  /// Update device state (typically called by IoT devices, but useful for testing)
  Future<DeviceState> updateDeviceState(
    String deviceId, {
    required bool online,
    required Map<String, dynamic> stateJson,
  }) async {
    try {
      final response = await supabase
          .from('device_state')
          .upsert({
            'device_id': deviceId,
            'reported_at': DateTime.now().toIso8601String(),
            'online': online,
            'state_json': stateJson,
          })
          .select()
          .single();

      return DeviceState.fromJson(response);
    } catch (e) {
      throw 'Failed to update device state: $e';
    }
  }

  /// Get shutter state from database
  /// Returns the position (0-100) or null if not found
  Future<int?> getShutterPosition(String deviceId) async {
    try {
      final response = await supabase
          .from('shutter_states')
          .select('position')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) return null;
      return response['position'] as int?;
    } catch (e) {
      debugPrint('Failed to get shutter position from database: $e');
      return null;
    }
  }

  // =====================================================
  // New Device Management Methods (with uniqueness and persistent naming)
  // =====================================================

  /// Create a device using the new claim-based approach
  Future<String> createDeviceWithClaiming({
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
    return await _deviceManagementRepo.claimDevice(
      topicBase: topicBase,
      macAddress: macAddress,
      channels: channels,
      defaultName: defaultName,
      homeId: homeId,
      roomId: roomId,
      deviceType: deviceType,
      channelCount: channelCount,
      matterType: matterType,
      metaJson: metaJson,
    );
  }

  /// Rename a device with persistent storage
  Future<void> renameDevicePersistent({
    required String deviceId,
    required String newName,
  }) async {
    return await _deviceManagementRepo.renameDevice(
      deviceId: deviceId,
      newName: newName,
    );
  }

  /// Rename a device channel with persistent storage
  Future<void> renameChannelPersistent({
    required String deviceId,
    required int channelNo,
    required String newLabel,
  }) async {
    return await _deviceManagementRepo.renameChannel(
      deviceId: deviceId,
      channelNo: channelNo,
      newLabel: newLabel,
    );
  }

  /// Update channel type (light or switch)
  Future<void> updateChannelType({
    required String deviceId,
    required int channelNo,
    required String channelType,
  }) async {
    return await _deviceManagementRepo.updateChannelType(
      deviceId: deviceId,
      channelNo: channelNo,
      channelType: channelType,
    );
  }

  /// Get device with channel information
  Future<DeviceWithChannels?> getDeviceWithChannels(String deviceId) async {
    return await _deviceManagementRepo.getDeviceWithChannels(deviceId);
  }

  /// Get all devices for the current user with channel information
  Future<List<DeviceWithChannels>> getUserDevicesWithChannels({
    String? homeId,
  }) async {
    return await _deviceManagementRepo.getUserDevicesWithChannels(
      homeId: homeId,
    );
  }

  /// Check if a device already exists
  Future<Map<String, dynamic>> checkDeviceExists({
    String? topicBase,
    String? macAddress,
  }) async {
    return await _deviceManagementRepo.checkDeviceExists(
      topicBase: topicBase,
      macAddress: macAddress,
    );
  }

  /// Get device channels for a specific device
  Future<List<DeviceChannel>> getDeviceChannels(String deviceId) async {
    return await _deviceManagementRepo.getDeviceChannels(deviceId);
  }
}
