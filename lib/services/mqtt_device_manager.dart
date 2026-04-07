import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../models/device.dart';
import '../services/enhanced_mqtt_service.dart';
import '../services/panel_mqtt_service.dart';

/// Centralized MQTT device manager for handling device operations
class MqttDeviceManager {
  final EnhancedMqttService _mqttService = EnhancedMqttService();

  // Track panel relay bridges already set up to avoid duplicate listeners
  final Set<String> _panelRelayBridged = {};

  // Device state management
  final Map<String, Map<String, dynamic>> _deviceStates = {};
  final Map<String, StreamController<Map<String, dynamic>>>
  _deviceStateControllers = {};
  // Debounce timers per device to avoid UI jank on burst messages
  final Map<String, Timer> _emitDebounceTimers = {};
  final Map<String, Timer> _stateTimeouts = {};

  // Batch operation management
  final Map<String, List<String>> _batchOperations = {};

  // Singleton pattern
  static final MqttDeviceManager _instance = MqttDeviceManager._internal();
  factory MqttDeviceManager() => _instance;
  MqttDeviceManager._internal() {
    _initializeManager();
  }

  /// Initialize the device manager
  void _initializeManager() {
    // Listen to MQTT connection state changes
    _mqttService.connectionStateStream.listen((state) {
      if (state == MqttConnectionState.connected) {
        _onMqttConnected();
      } else if (state == MqttConnectionState.disconnected) {
        _onMqttDisconnected();
      }
    });
  }

  /// Initialize with user ID and home ID
  Future<void> initialize(String userId, {String? homeId}) async {
    _mqttService.initialize(userId);
    // Note: homeId tracking removed to avoid circular dependencies
  }

  /// Connect to MQTT broker
  Future<bool> connect() async {
    return await _mqttService.connect();
  }

  /// Get the underlying MQTT service (for lifecycle management)
  EnhancedMqttService get mqttService => _mqttService;

  /// Register multiple devices for MQTT control
  Future<void> registerDevices(List<Device> devices) async {
    // Register devices in chunks to limit concurrent registrations.
    const maxConcurrent = 8; // Increased from 4 for faster registration
    for (int i = 0; i < devices.length; i += maxConcurrent) {
      final end = (i + maxConcurrent < devices.length)
          ? i + maxConcurrent
          : devices.length;
      final chunk = devices.sublist(i, end);
      await Future.wait(chunk.map((d) => registerDevice(d)));
      // Minimal pause between chunks
      if (end < devices.length) {
        await Future.delayed(
          const Duration(milliseconds: 50),
        ); // Reduced from 200ms
      }
    }
  }

  /// Register a single device for MQTT control
  Future<void> registerDevice(Device device) async {
    try {
      // Ensure a local controller exists immediately so callers can subscribe
      // to the manager stream even if MQTT registration is still in flight.
      if (!_deviceStateControllers.containsKey(device.id)) {
        _deviceStateControllers[device.id] =
            StreamController<Map<String, dynamic>>.broadcast();
      }

      // Register with underlying MQTT service (this subscribes to topics)
      await _mqttService.registerDevice(device);

      // Wire underlying MQTT stream to our controller, but guard against
      // multiple listeners and late registration.
      final mqttStream = _mqttService.getDeviceStateStream(device.id);
      if (mqttStream != null) {
        mqttStream.listen(
          (state) {
            _updateDeviceState(device.id, state);
          },
          onError: (e) {
            debugPrint('MQTT stream error for ${device.id}: $e');
          },
        );
      }

      // Panel relay bridge: if this device is a panel relay, wire PanelMqttService
      // state updates into this device's state stream so the dashboard card updates.
      // Panel relays use hbot/panels/{id}/relay/{n}/state (not Tasmota stat topics).
      if (_isPanelRelay(device)) {
        _bridgePanelRelayState(device);
        // Don't request state via Tasmota cmnd — panel relays don't respond to that.
        return;
      }

      // After registration request an immediate state to populate UI quickly
      // (fire-and-forget via microtask to avoid analyzer unawaited warnings)
      Future.microtask(() => requestDeviceState(device.id));
    } catch (e) {
      debugPrint('Failed to register device ${device.name}: $e');
    }
  }

  /// Unregister a device
  void unregisterDevice(String deviceId) {
    _mqttService.unregisterDevice(deviceId);
    _deviceStateControllers[deviceId]?.close();
    _deviceStateControllers.remove(deviceId);
    _deviceStates.remove(deviceId);
    _stateTimeouts[deviceId]?.cancel();
    _stateTimeouts.remove(deviceId);
    _panelRelayBridged.remove(deviceId);
  }

  // ─── Panel Relay Helpers ───────────────────────────────────────────────────

  /// Returns true if the device is a panel relay (paired through panel QR).
  bool _isPanelRelay(Device device) {
    return device.metaJson?['source'] == 'panel_pairing' &&
        device.metaJson?['panel_device_id'] != null &&
        device.metaJson?['panel_relay_index'] != null;
  }

  /// Wire PanelMqttService relay state updates into this device's state stream.
  /// Called once per device during registration to avoid duplicate listeners.
  void _bridgePanelRelayState(Device device) {
    if (_panelRelayBridged.contains(device.id)) return;
    _panelRelayBridged.add(device.id);

    final panelDeviceId = device.metaJson!['panel_device_id'] as String;
    final relayIndex = (device.metaJson!['panel_relay_index'] as num).toInt();

    // Subscribe to the panel on PanelMqttService (idempotent — safe to call multiple times)
    PanelMqttService().subscribeToPanel(panelDeviceId);

    // Bridge relay state updates into this device's state controller
    PanelMqttService().addRelayStateListener((pId, rIdx, isOn) {
      if (pId != panelDeviceId || rIdx != relayIndex) return;
      _updateDeviceState(device.id, {
        'POWER1': isOn ? 'ON' : 'OFF',
        'online': true,
      });
    });

    // Seed with current cached state if available
    final cached = PanelMqttService().getRelayState(panelDeviceId, relayIndex);
    if (cached != null) {
      _updateDeviceState(device.id, {
        'POWER1': cached ? 'ON' : 'OFF',
        'online': true,
      });
    }

    debugPrint('PanelRelay bridge: ${device.name} → panel $panelDeviceId relay $relayIndex');
  }

  /// Get device state stream
  Stream<Map<String, dynamic>>? getDeviceStateStream(String deviceId) {
    // Prefer manager-local stream when available (manager may inject or
    // transform messages). If the manager hasn't created a controller for
    // this device (e.g. registration didn't happen yet), fall back to the
    // underlying EnhancedMqttService stream so callers (UI/SmartHomeService)
    // still receive live MQTT updates. This decouples UI presence from
    // database persistence and reduces cases where a controllable device
    // appears offline due to DB write failures.
    if (_deviceStateControllers.containsKey(deviceId)) {
      return _deviceStateControllers[deviceId]!.stream;
    }

    // Fallback: return the raw stream from the underlying MQTT service.
    // This may be null if the MQTT service hasn't registered the device,
    // but when available it ensures real-time MQTT updates propagate.
    return _mqttService.getDeviceStateStream(deviceId);
  }

  /// Get current device state
  /// CRITICAL FIX: If manager doesn't have state yet, fall back to MQTT service
  /// This ensures UI can show cached state immediately on startup
  Map<String, dynamic>? getDeviceState(String deviceId) {
    // First try manager's local cache
    if (_deviceStates.containsKey(deviceId)) {
      return _deviceStates[deviceId];
    }

    // Fallback: get state from underlying MQTT service
    // This is important for initial UI render before first MQTT message arrives
    final mqttState = _mqttService.getDeviceState(deviceId);
    if (mqttState != null) {
      // Cache it locally for future calls
      _deviceStates[deviceId] = Map<String, dynamic>.from(mqttState);
      return _deviceStates[deviceId];
    }

    return null;
  }

  /// Get power state for a specific channel
  bool? getChannelPowerState(String deviceId, int channel) {
    final state = _deviceStates[deviceId];
    if (state == null) return null;

    final powerKey = 'POWER$channel';
    final powerValue = state[powerKey];

    if (powerValue is String) {
      return powerValue.toUpperCase() == 'ON';
    }

    return null;
  }

  /// Send power command to device channel
  Future<void> setChannelPower(String deviceId, int channel, bool on) async {
    // Route panel relay devices through PanelMqttService (not Tasmota cmnd topics)
    final device = _mqttService.getRegisteredDevice(deviceId);
    if (device != null && _isPanelRelay(device)) {
      final panelDeviceId = device.metaJson!['panel_device_id'] as String?;
      final relayIndex = (device.metaJson!['panel_relay_index'] as num?)?.toInt();
      if (panelDeviceId != null && relayIndex != null) {
        _updateOptimisticChannelState(deviceId, 1, on);
        await PanelMqttService().setRelay(panelDeviceId, relayIndex, on);
        return;
      }
    }

    try {
      // Capture previous state so we can revert if the device doesn't confirm
      final prevStateRaw = _deviceStates[deviceId]?['POWER$channel'];
      final prevState = prevStateRaw is String
          ? (prevStateRaw.toUpperCase() == 'ON')
          : (prevStateRaw == true);

      // Only apply optimistic update when we have an active MQTT connection
      if (_mqttService.connectionState == MqttConnectionState.connected) {
        // Send optimistic update first
        _updateOptimisticChannelState(deviceId, channel, on);
      }

      // Send MQTT command
      await _mqttService.sendPowerCommand(deviceId, channel, on);

      // Wait up to 1 second for the device to confirm the new POWER state
      // via the device state stream (stat/tele messages). If no confirmation
      // arrives, revert the optimistic update if applied.
      // response from the device.
      final expected = on ? 'ON' : 'OFF';
      final stream = getDeviceStateStream(deviceId);
      StreamSubscription<Map<String, dynamic>>? sub;
      final completer = Completer<bool>();

      if (stream != null) {
        sub = stream.listen((state) {
          try {
            final value = state['POWER$channel'];
            if (value != null) {
              final match =
                  (value == true) ||
                  (value.toString().toUpperCase() == expected);
              if (match) {
                if (!completer.isCompleted) completer.complete(true);
              }
            }
          } catch (_) {}
        });
      }

      try {
        final confirmed = await completer.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => false,
        );
        if (!confirmed) {
          // No confirmation: revert optimistic channel state if we set one
          if (_deviceStates[deviceId]?.containsKey('optimistic') == true) {
            _deviceStates[deviceId] ??= {};
            // Revert POWER state to previous known value (or OFF if unknown)
            if (prevStateRaw != null) {
              _deviceStates[deviceId]!['POWER$channel'] = prevStateRaw is String
                  ? prevStateRaw
                  : (prevState ? 'ON' : 'OFF');
            } else {
              _deviceStates[deviceId]!['POWER$channel'] = 'OFF';
            }

            // Clear optimistic flags
            _deviceStates[deviceId]!.remove('optimistic');
            _deviceStates[deviceId]!.remove('optimisticTimestamp');

            // Add a small marker that last command failed for UI/diagnostics
            _deviceStates[deviceId]!['lastCommandFailed'] = DateTime.now()
                .toIso8601String();

            // Debounced emit to avoid jank
            _emitDebounced(deviceId);
          }

          debugPrint(
            'No response from $deviceId channel $channel within 1s -> reverting optimistic state',
          );
        } else {
          // Confirmation received; clear optimistic flag and let normal flow continue
          _deviceStates[deviceId]?.remove('optimistic');
        }
      } catch (e) {
        debugPrint('Error waiting for confirmation: $e');
      } finally {
        await sub?.cancel();
        // Keep the existing reconciliation timeout logic as a fallback.
        // It will no-op if the state has already been confirmed.
        _setStateTimeout(deviceId, channel, on);
      }
    } catch (e) {
      // Revert optimistic update on error
      _updateOptimisticChannelState(deviceId, channel, !on);
      rethrow;
    }
  }

  /// Send bulk power command to all channels using POWER0
  Future<void> setBulkPower(String deviceId, bool on) async {
    // Route panel relay devices through PanelMqttService
    final device = _mqttService.getRegisteredDevice(deviceId);
    if (device != null && _isPanelRelay(device)) {
      final panelDeviceId = device.metaJson!['panel_device_id'] as String?;
      final relayIndex = (device.metaJson!['panel_relay_index'] as num?)?.toInt();
      if (panelDeviceId != null && relayIndex != null) {
        await PanelMqttService().setRelay(panelDeviceId, relayIndex, on);
        return;
      }
    }

    try {
      // Send MQTT bulk command using POWER0
      await _mqttService.sendBulkPowerCommand(deviceId, on);

      // Note: Optimistic updates removed to avoid dependency on device info
      // The device will respond with actual state via MQTT messages
    } catch (e) {
      debugPrint('Failed to set bulk power for device $deviceId: $e');
      rethrow;
    }
  }

  /// Toggle channel power state
  Future<void> toggleChannelPower(String deviceId, int channel) async {
    final currentState = getChannelPowerState(deviceId, channel);
    await setChannelPower(deviceId, channel, !(currentState ?? false));
  }

  /// Publish a custom command to a device
  /// This is useful for sending Tasmota commands like Timer1, Latitude, etc.
  /// Format: "Timer1 {json}" or "Command payload"
  Future<void> publishCommand(String deviceId, String fullCommand) async {
    try {
      // Get device to access tasmotaTopicBase
      final device = _mqttService.getRegisteredDevice(deviceId);
      if (device == null) {
        throw Exception('Device not registered: $deviceId');
      }

      if (device.tasmotaTopicBase == null) {
        throw Exception('Device has no MQTT topic base');
      }

      // Split command and payload
      final parts = fullCommand.split(' ');
      if (parts.isEmpty) return;

      final command = parts[0];
      final payload = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      debugPrint('📤 Publishing to ${device.deviceName}: $command = $payload');
      await _mqttService.sendCustomCommand(
        device.tasmotaTopicBase!,
        command,
        payload,
      );
    } catch (e) {
      debugPrint('Error publishing command to $deviceId: $e');
      rethrow;
    }
  }

  /// Send power command to multiple channels
  Future<void> setMultipleChannelsPower(
    String deviceId,
    Map<int, bool> channelStates,
  ) async {
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();
    _batchOperations[batchId] = [];

    try {
      for (final entry in channelStates.entries) {
        final channel = entry.key;
        final on = entry.value;

        // Add to batch tracking
        _batchOperations[batchId]!.add('$deviceId:$channel');

        // Send optimistic update
        _updateOptimisticChannelState(deviceId, channel, on);

        // Send MQTT command
        await _mqttService.sendPowerCommand(deviceId, channel, on);

        // Minimal delay between commands for faster responsiveness
        if (channelStates.entries.toList().last.key != channel) {
          await Future.delayed(
            const Duration(milliseconds: 10),
          ); // Reduced from 50ms
        }
      }
    } catch (e) {
      // Revert all optimistic updates on error
      for (final entry in channelStates.entries) {
        _updateOptimisticChannelState(deviceId, entry.key, !entry.value);
      }
      rethrow;
    } finally {
      _batchOperations.remove(batchId);
    }
  }

  /// Turn all channels on
  Future<void> turnAllChannelsOn(String deviceId) async {
    // Use bulk command instead of individual channel commands
    await setBulkPower(deviceId, true);
  }

  /// Turn all channels off
  Future<void> turnAllChannelsOff(String deviceId) async {
    // Use bulk command instead of individual channel commands
    await setBulkPower(deviceId, false);
  }

  /// Request current device state
  Future<void> requestDeviceState(String deviceId) async {
    // Panel relay devices don't respond to Tasmota STATE commands.
    // Their state arrives via PanelMqttService (hbot/panels/.../relay/.../state).
    final device = _mqttService.getRegisteredDevice(deviceId);
    if (device != null && _isPanelRelay(device)) return;
    await _mqttService.requestDeviceStatus(deviceId);
  }

  /// Configure Tasmota device for proper status reporting
  Future<void> configureTasmotaDevice(String deviceId) async {
    final device = _mqttService.getRegisteredDevice(deviceId);
    if (device != null && _isPanelRelay(device)) return;
    await _mqttService.configureTasmotaStatusReporting(deviceId);
  }

  /// Request device state immediately without throttling (for page loads)
  Future<void> requestDeviceStateImmediate(String deviceId) async {
    final device = _mqttService.getRegisteredDevice(deviceId);
    if (device != null && _isPanelRelay(device)) return;
    await _mqttService.requestDeviceStateImmediate(deviceId);
  }

  /// Request state for multiple devices
  Future<void> requestMultipleDeviceStates(List<String> deviceIds) async {
    // Use parallel requests for faster state retrieval
    await Future.wait(
      deviceIds.map((deviceId) => requestDeviceState(deviceId)),
    );
  }

  // =====================================================
  // Shutter Control Methods
  // =====================================================

  /// Open shutter
  Future<void> openShutter(String deviceId, int shutterIndex) async {
    try {
      await _mqttService.openShutter(deviceId, shutterIndex);
      debugPrint('Opened shutter $shutterIndex for device $deviceId');
    } catch (e) {
      debugPrint('Failed to open shutter for device $deviceId: $e');
      rethrow;
    }
  }

  /// Close shutter
  Future<void> closeShutter(String deviceId, int shutterIndex) async {
    try {
      await _mqttService.closeShutter(deviceId, shutterIndex);
      debugPrint('Closed shutter $shutterIndex for device $deviceId');
    } catch (e) {
      debugPrint('Failed to close shutter for device $deviceId: $e');
      rethrow;
    }
  }

  /// Stop shutter
  Future<void> stopShutter(String deviceId, int shutterIndex) async {
    try {
      await _mqttService.stopShutter(deviceId, shutterIndex);
      debugPrint('Stopped shutter $shutterIndex for device $deviceId');
    } catch (e) {
      debugPrint('Failed to stop shutter for device $deviceId: $e');
      rethrow;
    }
  }

  /// Set shutter position (0-100)
  Future<void> setShutterPosition(
    String deviceId,
    int shutterIndex,
    int position,
  ) async {
    try {
      await _mqttService.setShutterPosition(deviceId, shutterIndex, position);
      debugPrint(
        'Set shutter $shutterIndex position to $position% for device $deviceId',
      );
    } catch (e) {
      debugPrint('Failed to set shutter position for device $deviceId: $e');
      rethrow;
    }
  }

  /// Get shutter position from device state (0-100)
  /// Returns sanitized position: always finite int 0..100, never null/NaN/Infinity
  int getShutterPosition(String deviceId, int shutterIndex) {
    final state = _deviceStates[deviceId];
    if (state == null) return 0;

    // Tasmota reports shutter position as Shutter1, Shutter2, etc.
    final positionKey = 'Shutter$shutterIndex';
    final position = state[positionKey];

    int? parsedPosition;

    if (position is int) {
      parsedPosition = position;
    } else if (position is double) {
      // Guard against NaN/Infinity
      if (position.isFinite) {
        parsedPosition = position.round();
      }
    } else if (position is String) {
      parsedPosition = int.tryParse(position);
    } else if (position is Map<String, dynamic>) {
      // Handle object form: {"Position": 50, "Direction": 1, ...}
      final pos = position['Position'];
      if (pos is int) {
        parsedPosition = pos;
      } else if (pos is double && pos.isFinite) {
        parsedPosition = pos.round();
      } else if (pos is String) {
        parsedPosition = int.tryParse(pos);
      }
    }

    // Sanitize: if null or not finite → 0; else clamp 0..100
    if (parsedPosition == null) return 0;
    return parsedPosition.clamp(0, 100);
  }

  // =====================================================
  // End Shutter Control Methods
  // =====================================================

  /// Get connection state
  MqttConnectionState get connectionState => _mqttService.connectionState;

  /// Get connection state stream
  Stream<MqttConnectionState> get connectionStateStream =>
      _mqttService.connectionStateStream;

  /// Get debug messages
  List<String> get debugMessages => _mqttService.recentDebugMessages;

  /// Get debug stream
  Stream<String> get debugStream => _mqttService.debugStream;

  /// Expose device lastSeen and availability via the manager as convenience
  DateTime? getLastSeen(String deviceId) =>
      _mqttService.getDeviceLastSeen(deviceId);

  String? getDeviceAvailability(String deviceId) =>
      _mqttService.getDeviceAvailability(deviceId);

  /// Private methods

  void _updateDeviceState(String deviceId, Map<String, dynamic> state) {
    _deviceStates[deviceId] = Map<String, dynamic>.from(state);
    // Debounce rapid emissions per device to reduce UI jank
    _emitDebounced(deviceId);

    // Clear any pending timeouts for received states
    _clearStateTimeouts(deviceId, state);
  }

  void _emitDebounced(String deviceId) {
    // Cancel previous timer
    _emitDebounceTimers[deviceId]?.cancel();
    // Reduced debounce delay from 80ms to 20ms for faster UI updates
    _emitDebounceTimers[deviceId] = Timer(const Duration(milliseconds: 20), () {
      final cur = _deviceStates[deviceId];
      if (cur != null) {
        try {
          _deviceStateControllers[deviceId]?.add(
            Map<String, dynamic>.from(cur),
          );
        } catch (_) {}
      }
      _emitDebounceTimers.remove(deviceId);
    });
  }

  void _updateOptimisticChannelState(String deviceId, int channel, bool on) {
    _deviceStates[deviceId] ??= {};
    _deviceStates[deviceId]!['POWER$channel'] = on ? 'ON' : 'OFF';
    _deviceStates[deviceId]!['optimistic'] = true;
    _deviceStates[deviceId]!['optimisticTimestamp'] =
        DateTime.now().millisecondsSinceEpoch;

    debugPrint(
      'Applied optimistic update: $deviceId POWER$channel = ${on ? 'ON' : 'OFF'}',
    );
    _deviceStateControllers[deviceId]?.add(_deviceStates[deviceId]!);
  }

  void _setStateTimeout(String deviceId, int channel, bool expectedState) {
    final timeoutKey = '$deviceId:$channel';

    // Cancel existing timeout
    _stateTimeouts[timeoutKey]?.cancel();

    // Set new timeout (shortened to 3s): if we don't get a confirmation within
    // this window, request a status and allow higher-level logic to mark offline
    _stateTimeouts[timeoutKey] = Timer(const Duration(seconds: 3), () {
      // Check if state has been confirmed
      final currentState = getChannelPowerState(deviceId, channel);
      final deviceState = _deviceStates[deviceId];
      final isOptimistic = deviceState?.containsKey('optimistic') ?? false;

      // Only request status if:
      // 1. State doesn't match expected AND
      // 2. We're still in optimistic mode (no confirmation received)
      if (currentState != expectedState && isOptimistic) {
        debugPrint(
          'State timeout: requesting status for $deviceId channel $channel (expected: $expectedState, current: $currentState)',
        );
        requestDeviceState(deviceId);
      } else {
        debugPrint(
          'State timeout: no action needed for $deviceId channel $channel (confirmed: ${!isOptimistic})',
        );
      }
      _stateTimeouts.remove(timeoutKey);
    });
  }

  void _clearStateTimeouts(String deviceId, Map<String, dynamic> state) {
    state.forEach((key, value) {
      if (key.startsWith('POWER')) {
        // Extract channel number from POWER key
        final channelMatch = RegExp(r'POWER(\d+)').firstMatch(key);
        if (channelMatch != null) {
          final channel = channelMatch.group(1)!;
          final timeoutKey = '$deviceId:$channel';
          _stateTimeouts[timeoutKey]?.cancel();
          _stateTimeouts.remove(timeoutKey);
        }
      }
    });

    // Only remove optimistic flag if we received actual device state updates
    if (state.keys.any((key) => key.startsWith('POWER'))) {
      _deviceStates[deviceId]?.remove('optimistic');
      debugPrint('Cleared optimistic flag for device: $deviceId');
    }
  }

  // Removed _getDevice method to break circular dependency with SmartHomeService

  void _onMqttConnected() {
    debugPrint('MQTT Device Manager: Connected to broker');
    // Note: Device re-registration should be handled by SmartHomeService
    // when it detects MQTT reconnection
  }

  void _onMqttDisconnected() {
    debugPrint('MQTT Device Manager: Disconnected from broker');
    // Mark all device states as potentially stale
    for (final deviceId in _deviceStates.keys) {
      _deviceStates[deviceId]!['connection_state'] = 'disconnected';
      _deviceStateControllers[deviceId]?.add(_deviceStates[deviceId]!);
    }
  }

  // Removed _reregisterAllDevices method to break circular dependency with SmartHomeService
  // Device registration should be handled by SmartHomeService calling registerDevice directly

  /// Dispose resources
  void dispose() {
    for (final controller in _deviceStateControllers.values) {
      controller.close();
    }
    _deviceStateControllers.clear();

    for (final timer in _stateTimeouts.values) {
      timer.cancel();
    }
    _stateTimeouts.clear();

    _batchOperations.clear();
    _deviceStates.clear();
  }
}
