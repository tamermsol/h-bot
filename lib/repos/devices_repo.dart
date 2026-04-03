import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';
import '../demo/demo_data.dart';
import '../models/device.dart';
import '../models/device_state.dart';
import '../models/device_channel.dart';
import 'device_management_repo.dart';

class DevicesRepo {
  final DeviceManagementRepo _deviceManagementRepo = DeviceManagementRepo();

  /// List all devices in a home
  Future<List<Device>> listDevicesByHome(String homeId) async {
    if (isDemoMode) return DemoData.getDevices(homeId);
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
    if (isDemoMode) return DemoData.sharedDevices;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Step 1: Get shared device IDs from shared_devices table
      final sharedRows = await supabase
          .from('shared_devices')
          .select('device_id')
          .eq('shared_with_id', userId);

      final deviceIds = (sharedRows as List)
          .map((row) => row['device_id'] as String)
          .toList();

      debugPrint('listSharedDevices: Found ${deviceIds.length} shared device IDs for user $userId');
      if (deviceIds.isEmpty) return [];

      // Step 2: Try RPC first (bypasses all RLS)
      try {
        final rpcResponse = await supabase.rpc('get_shared_devices');
        if (rpcResponse != null && rpcResponse is List && rpcResponse.isNotEmpty) {
          final devices = rpcResponse
              .map((json) => Device.fromJson(json as Map<String, dynamic>))
              .toList();
          debugPrint('listSharedDevices: Got ${devices.length} via RPC');
          return devices;
        }
      } catch (rpcErr) {
        debugPrint('listSharedDevices: RPC failed: $rpcErr');
      }

      // Step 3: Fallback — query devices table directly with inFilter
      try {
        final devicesResponse = await supabase
            .from('devices')
            .select('*')
            .inFilter('id', deviceIds)
            .eq('is_deleted', false);

        final devices = (devicesResponse as List).map((json) {
          // devices table uses 'inserted_at' not 'created_at', map it
          final map = Map<String, dynamic>.from(json);
          if (!map.containsKey('created_at') && map.containsKey('inserted_at')) {
            map['created_at'] = map['inserted_at'];
          }
          return Device.fromJson(map);
        }).toList();
        debugPrint('listSharedDevices: Got ${devices.length} via direct query');
        return devices;
      } catch (directErr) {
        debugPrint('listSharedDevices: Direct query failed: $directErr');
      }

      // Step 4: Last resort — build minimal Device objects from shared_devices join
      try {
        final joinResponse = await supabase
            .from('shared_devices')
            .select('device_id, devices!inner(id, display_name, device_type, home_id, room_id, topic_base, mac_address, owner_user_id, online, channels, channel_count, inserted_at, updated_at, is_deleted)')
            .eq('shared_with_id', userId);

        final devices = (joinResponse as List).where((item) {
          return item['devices'] != null;
        }).map((item) {
          final d = Map<String, dynamic>.from(item['devices']);
          d['name'] = d['display_name'] ?? 'Shared Device';
          d['created_at'] = d['inserted_at'] ?? DateTime.now().toIso8601String();
          d['tasmota_topic_base'] = d['topic_base'];
          return Device.fromJson(d);
        }).toList();
        debugPrint('listSharedDevices: Got ${devices.length} via join fallback');
        return devices;
      } catch (joinErr) {
        debugPrint('listSharedDevices: Join fallback failed: $joinErr');
      }

      return [];
    } catch (e) {
      debugPrint('listSharedDevices: FAILED: $e');
      return [];
    }
  }

  /// List all devices in a room
  Future<List<Device>> listDevicesByRoom(String roomId) async {
    if (isDemoMode) {
      return DemoData.getDevices('demo-home-001')
          .where((d) => d.roomId == roomId)
          .toList();
    }
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
  ///
  /// DB column mapping:
  ///   Dart param       → DB column
  ///   name             → display_name
  ///   tasmotaTopicBase → topic_base
  ///   (auto)           → inserted_at  (server-generated)
  ///   (auto)           → owner_user_id (from auth)
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
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final insertData = <String, dynamic>{
        'home_id': homeId,
        'room_id': roomId,
        'display_name': name,
        'device_type': deviceType.name,
        'channels': channels,
        'topic_base': tasmotaTopicBase,
        'owner_user_id': userId,
        'matter_type': matterType,
        'meta_json': metaJson,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('devices')
          .insert(insertData)
          .select()
          .single();

      // Map DB columns back to model field names
      final mapped = Map<String, dynamic>.from(response);
      if (!mapped.containsKey('created_at') && mapped.containsKey('inserted_at')) {
        mapped['created_at'] = mapped['inserted_at'];
      }
      if (!mapped.containsKey('tasmota_topic_base') && mapped.containsKey('topic_base')) {
        mapped['tasmota_topic_base'] = mapped['topic_base'];
      }
      if (!mapped.containsKey('name') && mapped.containsKey('display_name')) {
        mapped['name'] = mapped['display_name'];
      }

      return Device.fromJson(mapped);
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

      if (name != null) updates['display_name'] = name;
      if (deviceType != null) updates['device_type'] = deviceType.name;
      if (channels != null) updates['channels'] = channels;
      if (tasmotaTopicBase != null) {
        updates['topic_base'] = tasmotaTopicBase;
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
