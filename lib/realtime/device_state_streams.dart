import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../models/device_state.dart';

class DeviceStateStreams {
  static final DeviceStateStreams _instance = DeviceStateStreams._internal();
  factory DeviceStateStreams() => _instance;
  DeviceStateStreams._internal();

  final Map<String, StreamController<DeviceState>> _controllers = {};
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, DeviceState?> _currentStates = {};

  /// Get a stream for a specific device's state changes
  Stream<DeviceState> watchDeviceState(String deviceId) {
    if (!_controllers.containsKey(deviceId)) {
      _controllers[deviceId] = StreamController<DeviceState>.broadcast();
      _subscribeToDevice(deviceId);
    }
    return _controllers[deviceId]!.stream;
  }

  /// Subscribe to realtime updates for multiple devices (batched)
  Future<void> subscribeToDevices(List<String> deviceIds) async {
    // Group devices into batches to avoid query limits
    const batchSize = 50;
    final batches = <List<String>>[];

    for (int i = 0; i < deviceIds.length; i += batchSize) {
      batches.add(deviceIds.skip(i).take(batchSize).toList());
    }

    // Subscribe to each batch
    for (int i = 0; i < batches.length; i++) {
      await _subscribeToBatch(batches[i], i);
    }
  }

  /// Subscribe to a batch of devices
  Future<void> _subscribeToBatch(List<String> deviceIds, int batchIndex) async {
    final channelName = 'device_state_batch_$batchIndex';

    // Unsubscribe from existing channel if it exists
    if (_channels.containsKey(channelName)) {
      await _channels[channelName]!.unsubscribe();
    }

    final channel = supabase.channel(channelName);

    // Subscribe to all device_state changes for this batch
    // Note: Supabase realtime doesn't support 'in' filters directly
    // We'll filter in the callback instead
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'device_state',
      callback: (payload) {
        final deviceId = payload.newRecord['device_id'] as String?;
        if (deviceId != null && deviceIds.contains(deviceId)) {
          _handleDeviceStateChange(payload);
        }
      },
    );

    channel.subscribe();
    _channels[channelName] = channel;
  }

  /// Subscribe to a single device
  void _subscribeToDevice(String deviceId) {
    final channelName = 'device_state_$deviceId';

    // Don't create duplicate subscriptions
    if (_channels.containsKey(channelName)) return;

    final channel = supabase.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'device_state',
      callback: (payload) {
        final payloadDeviceId = payload.newRecord['device_id'] as String?;
        if (payloadDeviceId == deviceId) {
          _handleDeviceStateChange(payload);
        }
      },
    );

    channel.subscribe();
    _channels[channelName] = channel;
  }

  /// Handle device state change from realtime with enhanced propagation
  void _handleDeviceStateChange(PostgresChangePayload payload) {
    try {
      final deviceId = payload.newRecord['device_id'] as String?;
      if (deviceId == null) return;

      DeviceState? newState;
      String changeType = 'unknown';

      if (payload.eventType == PostgresChangeEvent.delete) {
        // Device state was deleted, emit null or last known state
        newState = _currentStates[deviceId];
        changeType = 'delete';
      } else {
        // INSERT or UPDATE
        final record = payload.newRecord;
        newState = DeviceState.fromJson(record);

        // Check if this is a meaningful state change
        final previousState = _currentStates[deviceId];
        final hasStateChanged = _hasSignificantStateChange(
          previousState,
          newState,
        );

        if (hasStateChanged) {
          _currentStates[deviceId] = newState;
          changeType = payload.eventType == PostgresChangeEvent.insert
              ? 'insert'
              : 'update';

          debugPrint(
            '📡 Real-time state change detected for device $deviceId: $changeType',
          );
          debugPrint('   Online: ${newState.online}');
          debugPrint('   State: ${newState.stateJson}');
        } else {
          // No significant change, skip emission to prevent unnecessary UI updates
          return;
        }
      }

      // Emit to the specific device stream with enhanced metadata
      if (_controllers.containsKey(deviceId) && newState != null) {
        _controllers[deviceId]!.add(newState);

        debugPrint(
          '✅ Emitted real-time state update for device $deviceId (type: $changeType)',
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling device state change: $e');
      debugPrint('   Payload: ${payload.newRecord}');
    }
  }

  /// Check if there's a significant state change worth propagating
  bool _hasSignificantStateChange(DeviceState? previous, DeviceState current) {
    if (previous == null) return true; // First state is always significant

    // Check online status change
    if (previous.online != current.online) return true;

    // Check for power state changes in state_json
    final prevStateJson = previous.stateJson;
    final currStateJson = current.stateJson;

    // Look for POWER1-POWER8 changes
    for (int i = 1; i <= 8; i++) {
      final powerKey = 'POWER$i';
      final prevPower = prevStateJson[powerKey];
      final currPower = currStateJson[powerKey];

      if (prevPower != currPower) {
        debugPrint(
          '   Power state change detected: $powerKey $prevPower → $currPower',
        );
        return true;
      }
    }

    // Check for other significant changes (uptime, connectivity, etc.)
    final significantKeys = ['connected', 'channels', 'rssi'];
    for (final key in significantKeys) {
      if (prevStateJson[key] != currStateJson[key]) {
        debugPrint(
          '   Significant state change detected: $key ${prevStateJson[key]} → ${currStateJson[key]}',
        );
        return true;
      }
    }

    return false; // No significant changes detected
  }

  /// Get the current cached state for a device
  DeviceState? getCurrentState(String deviceId) {
    return _currentStates[deviceId];
  }

  /// Load initial state for a device
  Future<void> loadInitialState(String deviceId) async {
    try {
      final response = await supabase
          .from('device_state')
          .select('*')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response != null) {
        final state = DeviceState.fromJson(response);
        _currentStates[deviceId] = state;

        // Emit initial state if someone is listening
        if (_controllers.containsKey(deviceId)) {
          _controllers[deviceId]!.add(state);
        }
      }
    } catch (e) {
      debugPrint('Error loading initial state for device $deviceId: $e');
    }
  }

  /// Load initial states for multiple devices
  Future<void> loadInitialStates(List<String> deviceIds) async {
    if (deviceIds.isEmpty) return;

    try {
      // Load states in batches
      const batchSize = 100;
      for (int i = 0; i < deviceIds.length; i += batchSize) {
        final batch = deviceIds.skip(i).take(batchSize).toList();

        final response = await supabase
            .from('device_state')
            .select('*')
            .inFilter('device_id', batch);

        for (final stateJson in response) {
          final state = DeviceState.fromJson(stateJson);
          final deviceId = state.deviceId;
          _currentStates[deviceId] = state;

          // Emit initial state if someone is listening
          if (_controllers.containsKey(deviceId)) {
            _controllers[deviceId]!.add(state);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading initial states: $e');
    }
  }

  /// Unsubscribe from a device
  Future<void> unsubscribeFromDevice(String deviceId) async {
    final channelName = 'device_state_$deviceId';

    if (_channels.containsKey(channelName)) {
      await _channels[channelName]!.unsubscribe();
      _channels.remove(channelName);
    }

    if (_controllers.containsKey(deviceId)) {
      await _controllers[deviceId]!.close();
      _controllers.remove(deviceId);
    }

    _currentStates.remove(deviceId);
  }

  /// Unsubscribe from all devices
  Future<void> unsubscribeFromAll() async {
    // Close all channels
    for (final channel in _channels.values) {
      await channel.unsubscribe();
    }
    _channels.clear();

    // Close all controllers
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();

    _currentStates.clear();
  }

  /// Clean up resources
  Future<void> dispose() async {
    await unsubscribeFromAll();
  }
}
