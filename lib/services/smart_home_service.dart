library;

/// SmartHomeService - Main facade for smart home operations
///
/// Usage:
/// ```dart
/// final service = SmartHomeService();
///
/// // Get user's homes
/// final homes = await service.getMyHomes();
///
/// // Load devices with state
/// final devices = await service.getDevicesWithState(homeId);
///
/// // Watch device state changes
/// service.watchDeviceState(deviceId).listen((state) {
///   print('Device ${state.deviceId} is ${state.online ? 'online' : 'offline'}');
/// });
///
/// // Create and run scenes
/// final scene = await service.createScene(homeId, 'Good Night');
/// await service.runScene(scene.id);
/// ```

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/device.dart';
import '../models/device_state.dart';
import '../models/scene.dart';
import '../models/scene_step.dart';
import '../models/scene_trigger.dart';
import '../models/scene_run.dart';
import '../models/wifi_profile.dart';
import '../repos/homes_repo.dart';
import '../repos/rooms_repo.dart';
import '../repos/devices_repo.dart';
import '../repos/scenes_repo.dart';
import '../repos/wifi_profiles_repo.dart';
import '../realtime/device_state_streams.dart';
import 'mqtt_device_manager.dart';
import 'device_event_tracker.dart';
import 'panel_mqtt_service.dart';

class SmartHomeService {
  static final SmartHomeService _instance = SmartHomeService._internal();
  factory SmartHomeService() => _instance;
  SmartHomeService._internal();

  final _homesRepo = HomesRepo();
  final _roomsRepo = RoomsRepo();
  final _devicesRepo = DevicesRepo();
  final _scenesRepo = ScenesRepo();
  final _wifiProfilesRepo = WiFiProfilesRepo();
  final _deviceStreams = DeviceStateStreams();
  final _mqttDeviceManager = MqttDeviceManager();

  // Cache for current home to avoid repeated queries
  String? _currentHomeId;
  List<String>? _currentDeviceIds;

  /// Get all homes the current user has access to
  Future<List<Home>> getMyHomes() async {
    return await _homesRepo.listMyHomes();
  }

  /// Create a new home
  Future<Home> createHome(String name) async {
    return await _homesRepo.createHome(name);
  }

  /// Rename a home
  Future<void> renameHome(String homeId, String name) async {
    await _homesRepo.renameHome(homeId, name);
  }

  /// Delete a home
  Future<void> deleteHome(String homeId) async {
    // Clean up realtime subscriptions if this is the current home
    if (_currentHomeId == homeId) {
      await _deviceStreams.unsubscribeFromAll();
      _currentHomeId = null;
      _currentDeviceIds = null;
    }
    await _homesRepo.deleteHome(homeId);
  }

  /// Get all rooms in a home
  Future<List<Room>> getRooms(String homeId) async {
    return await _roomsRepo.listRooms(homeId);
  }

  /// Create a new room
  Future<Room> createRoom(String homeId, String name) async {
    final sortOrder = await _roomsRepo.getNextSortOrder(homeId);
    return await _roomsRepo.createRoom(homeId, name, sortOrder);
  }

  /// Update a room
  Future<Room> updateRoom(String roomId, {String? name, int? sortOrder}) async {
    return await _roomsRepo.updateRoom(
      roomId,
      name: name,
      sortOrder: sortOrder,
    );
  }

  /// Delete a room
  Future<void> deleteRoom(String roomId) async {
    await _roomsRepo.deleteRoom(roomId);
  }

  /// Get all devices with their current state for a home
  Future<List<DeviceWithState>> getDevicesWithState(String homeId) async {
    final devices = await _devicesRepo.listDevicesWithState(homeId);

    // Set up realtime subscriptions if this is a new home
    if (_currentHomeId != homeId) {
      await _deviceStreams.unsubscribeFromAll();
      _currentHomeId = homeId;
      _currentDeviceIds = devices.map((d) => d.id).toList();

      if (_currentDeviceIds!.isNotEmpty) {
        await _deviceStreams.subscribeToDevices(_currentDeviceIds!);
        await _deviceStreams.loadInitialStates(_currentDeviceIds!);
      }
    }

    return devices;
  }

  /// Get devices in a specific room
  Future<List<Device>> getDevicesByRoom(String roomId) async {
    return await _devicesRepo.listDevicesByRoom(roomId);
  }

  /// Get devices in a specific home (metadata only, no state snapshot)
  Future<List<Device>> getDevicesByHome(String homeId) async {
    return await _devicesRepo.listDevicesByHome(homeId);
  }

  /// Get a single device by ID
  Future<Device?> getDeviceById(String deviceId) async {
    try {
      return await _devicesRepo.getDevice(deviceId);
    } catch (e) {
      debugPrint('❌ Error getting device by ID: $e');
      return null;
    }
  }

  /// Get devices for the current home (compatibility method)
  Future<List<Device>> getDevicesForCurrentHome() async {
    if (_currentHomeId == null) {
      throw Exception('No current home set. Call getDevicesWithState() first.');
    }
    return await _devicesRepo.listDevicesByHome(_currentHomeId!);
  }

  /// Watch realtime state changes for a device
  Stream<DeviceState> watchDeviceState(String deviceId) {
    return _deviceStreams.watchDeviceState(deviceId);
  }

  /// Watch MQTT-only device state changes
  /// CRITICAL: State comes ONLY from MQTT, never from database
  /// Database is for metadata only (device name, topic, type, etc.)
  Stream<Map<String, dynamic>> watchCombinedDeviceState(String deviceId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    final mqttStateStream = _mqttDeviceManager.getDeviceStateStream(deviceId);

    Map<String, dynamic>? lastEmittedState;
    Map<String, dynamic>? latestMqttState;

    // Build state from MQTT ONLY - no database state
    Map<String, dynamic> buildMergedState() {
      final merged = <String, dynamic>{
        'deviceId': deviceId,
        'source': latestMqttState != null ? 'mqtt' : 'none',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // If MQTT state is present, use it exclusively
      if (latestMqttState != null) {
        // Copy everything from MQTT state - this is the ONLY source of truth
        merged.addAll(latestMqttState!);
        merged['source'] = 'mqtt';
        merged['timestamp'] =
            (latestMqttState!['timestamp'] ?? merged['timestamp']);

        // Normalize health/online
        if (latestMqttState!.containsKey('health')) {
          merged['health'] = latestMqttState!['health'];
          merged['online'] =
              (latestMqttState!['health'] as String).toUpperCase() == 'ONLINE';
        } else if (latestMqttState!.containsKey('online')) {
          merged['online'] = latestMqttState!['online'];
        }

        // Ensure POWER1..POWER8 reflect MQTT only
        for (int i = 1; i <= 8; i++) {
          final key = 'POWER$i';
          if (latestMqttState!.containsKey(key)) {
            merged[key] = latestMqttState![key];
          } else {
            // If MQTT did not report a specific POWER key, don't fill it
            merged.remove(key);
          }
        }
      } else {
        // No MQTT data -> treat as offline
        merged['online'] = false;
        merged['health'] = 'OFFLINE';
        // Leave POWER/Shutter keys absent so UI knows there is no realtime info
      }

      return merged;
    }

    // Helper function to check if state has meaningful changes
    bool hasSignificantChange(
      Map<String, dynamic>? prev,
      Map<String, dynamic> curr,
    ) {
      if (prev == null) return true;
      // Check power keys
      for (int i = 1; i <= 8; i++) {
        final key = 'POWER$i';
        if (prev[key] != curr[key]) return true;
      }
      // Check shutter positions (Shutter1..Shutter4)
      // CRITICAL FIX: Compare shutter position values, not Map references
      for (int i = 1; i <= 4; i++) {
        final key = 'Shutter$i';
        final prevShutter = prev[key];
        final currShutter = curr[key];

        // If one exists and the other doesn't, it's a change
        if ((prevShutter == null) != (currShutter == null)) return true;

        // If both exist, compare the Position value (not the Map reference)
        if (prevShutter != null && currShutter != null) {
          // Extract position from Map or use value directly
          final prevPos = prevShutter is Map
              ? prevShutter['Position']
              : prevShutter;
          final currPos = currShutter is Map
              ? currShutter['Position']
              : currShutter;
          if (prevPos != currPos) return true;

          // Also check Direction for real-time movement updates
          if (prevShutter is Map && currShutter is Map) {
            if (prevShutter['Direction'] != currShutter['Direction']) {
              return true;
            }
          }
        }
      }
      // Prefer health differences
      final ph = prev['health'] as String?;
      final ch = curr['health'] as String?;
      if (ph != ch) return true;
      // Online flag change
      if (prev['online'] != curr['online']) return true;
      return false;
    }

    void maybeEmit() {
      final merged = buildMergedState();
      if (hasSignificantChange(lastEmittedState, merged)) {
        lastEmittedState = Map.from(merged);
        controller.add(merged);

        // Track device events for activity log + notifications
        try {
          DeviceEventTracker().trackState(deviceId, deviceId, merged);
        } catch (_) {}

        // Debug logging for state changes
        debugPrint(
          '🔄 [smart_home_service] State change emitted for device $deviceId: '
          'source=${merged['source']}, online=${merged['online']}, '
          'POWER1=${merged['POWER1']}, Shutter1=${merged['Shutter1']}',
        );
      } else {
        // Debug logging for skipped emissions
        debugPrint(
          '⏭️ [smart_home_service] State change skipped (no significant change) for device $deviceId',
        );
      }
    }

    // Get initial cached state from MQTT manager and emit immediately
    // This prevents flicker by showing cached state before MQTT updates arrive
    final initialCachedState = _mqttDeviceManager.getDeviceState(deviceId);
    if (initialCachedState != null) {
      latestMqttState = {
        'source': 'mqtt_cache',
        'deviceId': deviceId,
        'timestamp':
            initialCachedState['lastUpdated'] ??
            DateTime.now().millisecondsSinceEpoch,
        ...initialCachedState,
      };
      // Emit initial cached state immediately so StreamBuilder has data
      final initialMerged = buildMergedState();
      lastEmittedState = Map.from(initialMerged);
      // Schedule emission after stream is returned to avoid sync emission
      Future.microtask(() {
        controller.add(initialMerged);
        debugPrint(
          '📤 [smart_home_service] Emitted initial cached state for device $deviceId: '
          'POWER1=${initialMerged['POWER1']}, Shutter1=${initialMerged['Shutter1']}',
        );
      });
    } else {
      debugPrint(
        '⚠️ [smart_home_service] No cached state for device $deviceId - will wait for MQTT',
      );
    }

    // Listen to MQTT state changes ONLY - no database subscription
    StreamSubscription<Map<String, dynamic>>? mqttSubscription;
    if (mqttStateStream != null) {
      mqttSubscription = mqttStateStream.listen((mqttState) {
        latestMqttState = {
          'source': 'mqtt',
          'deviceId': deviceId,
          'timestamp':
              mqttState['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
          ...mqttState,
        };
        maybeEmit();
      });
    }

    // Clean up subscription when controller is closed
    controller.onCancel = () {
      mqttSubscription?.cancel();
    };

    return controller.stream;
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
    final device = await _devicesRepo.createDevice(
      homeId,
      roomId: roomId,
      name: name,
      deviceType: deviceType,
      channels: channels,
      tasmotaTopicBase: tasmotaTopicBase,
      matterType: matterType,
      metaJson: metaJson,
    );

    // Add to realtime subscriptions if this is the current home
    if (_currentHomeId == homeId) {
      _currentDeviceIds?.add(device.id);
      // Ensure we both load the initial DB snapshot and subscribe to realtime
      // updates for this newly created device so the UI and other services
      // receive the state immediately without requiring an app restart.
      await _deviceStreams.loadInitialState(device.id);
      try {
        await _deviceStreams.subscribeToDevices([device.id]);
      } catch (e) {
        debugPrint(
          'Warning: failed to subscribe to realtime for $device.id: $e',
        );
      }

      // Register with MQTT device manager if device has MQTT topic
      if (device.tasmotaTopicBase != null) {
        await _mqttDeviceManager.registerDevice(device);
      }
    }

    return device;
  }

  /// Update a device
  ///
  /// To clear the room assignment, pass clearRoom: true
  Future<Device> updateDevice(
    String deviceId, {
    String? roomId,
    String? name,
    DeviceType? deviceType,
    int? channels,
    String? tasmotaTopicBase,
    String? matterType,
    Map<String, dynamic>? metaJson,
    bool clearRoom = false,
  }) async {
    return await _devicesRepo.updateDevice(
      deviceId,
      roomId: roomId,
      name: name,
      deviceType: deviceType,
      channels: channels,
      tasmotaTopicBase: tasmotaTopicBase,
      matterType: matterType,
      metaJson: metaJson,
      clearRoom: clearRoom,
    );
  }

  /// Delete a device
  Future<void> deleteDevice(String deviceId) async {
    // Unsubscribe from Supabase real-time streams
    await _deviceStreams.unsubscribeFromDevice(deviceId);

    // Unregister from MQTT device manager
    _mqttDeviceManager.unregisterDevice(deviceId);

    // Remove from current device tracking
    _currentDeviceIds?.remove(deviceId);

    // Delete from database
    await _devicesRepo.deleteDevice(deviceId);
  }

  /// Configure Tasmota device for proper status reporting
  Future<void> configureTasmotaDevice(String deviceId) async {
    await _mqttDeviceManager.configureTasmotaDevice(deviceId);
  }

  /// Update device state (for testing purposes)
  Future<DeviceState> updateDeviceState(
    String deviceId, {
    required bool online,
    required Map<String, dynamic> stateJson,
  }) async {
    return await _devicesRepo.updateDeviceState(
      deviceId,
      online: online,
      stateJson: stateJson,
    );
  }

  /// Get all scenes in a home
  Future<List<Scene>> getScenes(String homeId) async {
    return await _scenesRepo.listScenes(homeId);
  }

  /// Get a single scene by ID
  Future<Scene> getScene(String sceneId) async {
    return await _scenesRepo.getScene(sceneId);
  }

  /// Create a new scene
  Future<Scene> createScene(
    String homeId,
    String name, {
    bool isEnabled = true,
    int? iconCode,
    int? colorValue,
  }) async {
    return await _scenesRepo.createScene(
      homeId,
      name,
      isEnabled: isEnabled,
      iconCode: iconCode,
      colorValue: colorValue,
    );
  }

  /// Update a scene
  Future<Scene> updateScene(
    String sceneId, {
    String? name,
    bool? isEnabled,
    int? iconCode,
    int? colorValue,
  }) async {
    return await _scenesRepo.updateScene(
      sceneId,
      name: name,
      isEnabled: isEnabled,
      iconCode: iconCode,
      colorValue: colorValue,
    );
  }

  /// Delete a scene
  Future<void> deleteScene(String sceneId) async {
    await _scenesRepo.deleteScene(sceneId);
  }

  /// Run a scene and notify panels
  Future<SceneRun> runScene(String sceneId) async {
    final result = await _scenesRepo.runScene(sceneId);
    // Notify all subscribed H-Bot panels so they can update their display
    PanelMqttService().executeScene(sceneId);
    return result;
  }

  /// Get scene steps
  Future<List<SceneStep>> getSceneSteps(String sceneId) async {
    return await _scenesRepo.listSceneSteps(sceneId);
  }

  /// Create a scene step
  Future<SceneStep> createSceneStep(
    String sceneId,
    int stepOrder,
    Map<String, dynamic> actionJson,
  ) async {
    return await _scenesRepo.createSceneStep(sceneId, stepOrder, actionJson);
  }

  /// Delete all scene steps for a scene
  Future<void> deleteSceneSteps(String sceneId) async {
    await _scenesRepo.deleteSceneSteps(sceneId);
  }

  /// Get scene triggers
  Future<List<SceneTrigger>> getSceneTriggers(String sceneId) async {
    return await _scenesRepo.listSceneTriggers(sceneId);
  }

  /// Create a scene trigger
  Future<SceneTrigger> createSceneTrigger(
    String sceneId,
    TriggerKind kind,
    Map<String, dynamic> configJson, {
    bool isEnabled = true,
  }) async {
    return await _scenesRepo.createSceneTrigger(
      sceneId,
      kind,
      configJson,
      isEnabled: isEnabled,
    );
  }

  /// Delete a scene trigger
  Future<void> deleteSceneTrigger(String triggerId) async {
    await _scenesRepo.deleteSceneTrigger(triggerId);
  }

  /// Get scene run history
  Future<List<SceneRun>> getSceneRuns(String sceneId, {int limit = 50}) async {
    return await _scenesRepo.listSceneRuns(sceneId, limit: limit);
  }

  // ============================================================================
  // Wi-Fi Profile Management
  // ============================================================================

  /// Get all Wi-Fi profiles for the current user
  Future<List<WiFiProfile>> getWiFiProfiles() async {
    return await _wifiProfilesRepo.getUserProfiles();
  }

  /// Get the default Wi-Fi profile
  Future<WiFiProfile?> getDefaultWiFiProfile() async {
    return await _wifiProfilesRepo.getDefaultProfile();
  }

  /// Create a new Wi-Fi profile
  Future<WiFiProfile> createWiFiProfile(WiFiProfileRequest request) async {
    return await _wifiProfilesRepo.createProfile(request);
  }

  /// Update an existing Wi-Fi profile
  Future<WiFiProfile> updateWiFiProfile(
    String profileId,
    WiFiProfileRequest request,
  ) async {
    return await _wifiProfilesRepo.updateProfile(profileId, request);
  }

  /// Delete a Wi-Fi profile
  Future<void> deleteWiFiProfile(String profileId) async {
    return await _wifiProfilesRepo.deleteProfile(profileId);
  }

  /// Set a Wi-Fi profile as default
  Future<WiFiProfile> setDefaultWiFiProfile(String profileId) async {
    return await _wifiProfilesRepo.setAsDefault(profileId);
  }

  /// Find Wi-Fi profile by SSID
  Future<WiFiProfile?> findWiFiProfileBySSID(String ssid) async {
    return await _wifiProfilesRepo.findBySSID(ssid);
  }

  /// Watch Wi-Fi profiles for real-time updates
  Stream<List<WiFiProfile>> watchWiFiProfiles() {
    return _wifiProfilesRepo.watchUserProfiles();
  }

  /// Refresh device registrations (for app lifecycle management)
  Future<void> refreshDeviceRegistrations() async {
    try {
      debugPrint('🔄 Refreshing device registrations...');

      // Re-register devices for current home if available
      if (_currentHomeId != null && _currentDeviceIds != null) {
        final devices = await _devicesRepo.listDevicesByHome(_currentHomeId!);

        if (devices.isNotEmpty) {
          debugPrint('📋 Re-registering ${devices.length} devices...');

          // Re-register devices in batches
          const batchSize = 10;
          for (int i = 0; i < devices.length; i += batchSize) {
            final batch = devices.skip(i).take(batchSize).toList();

            try {
              await _mqttDeviceManager.registerDevices(batch);
              debugPrint('✅ Re-registered batch of ${batch.length} devices');

              // Small delay between batches
              if (i + batchSize < devices.length) {
                await Future.delayed(const Duration(milliseconds: 500));
              }
            } catch (e) {
              debugPrint('❌ Error re-registering device batch: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing device registrations: $e');
    }
  }

  /// Refresh all device states (for app lifecycle management)
  Future<void> refreshAllDeviceStates() async {
    try {
      debugPrint('🔄 Refreshing all device states...');

      // Request fresh state for current home devices
      if (_currentHomeId != null && _currentDeviceIds != null) {
        // Use parallel requests for faster state refresh
        await Future.wait(
          _currentDeviceIds!.map((deviceId) async {
            try {
              await _mqttDeviceManager.requestDeviceState(deviceId);
            } catch (e) {
              debugPrint('❌ Error refreshing state for device $deviceId: $e');
            }
          }),
        );
      }

      debugPrint('✅ Device state refresh completed');
    } catch (e) {
      debugPrint('❌ Error refreshing device states: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _deviceStreams.dispose();
    _currentHomeId = null;
    _currentDeviceIds = null;
  }
}
