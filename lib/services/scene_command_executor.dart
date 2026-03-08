import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import 'mqtt_device_manager.dart';
import 'enhanced_mqtt_service.dart';

/// Service that listens for scene commands from the edge function
/// and executes them via MQTT
///
/// This service uses Supabase Realtime to listen for new commands
/// inserted by the scene-trigger-monitor edge function.
class SceneCommandExecutor {
  static final SceneCommandExecutor _instance =
      SceneCommandExecutor._internal();

  factory SceneCommandExecutor() {
    return _instance;
  }

  SceneCommandExecutor._internal();

  final MqttDeviceManager _mqttDeviceManager = MqttDeviceManager();
  final EnhancedMqttService _enhancedMqttService = EnhancedMqttService();

  RealtimeChannel? _channel;
  bool _isListening = false;

  /// Start listening for scene commands
  void start() {
    if (_isListening) {
      debugPrint('🎬 SceneCommandExecutor: Already listening');
      return;
    }

    debugPrint('🎬 SceneCommandExecutor: Starting...');

    // Subscribe to realtime changes on scene_commands table
    _channel = supabase
        .channel('scene_commands')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scene_commands',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'executed',
            value: false,
          ),
          callback: (payload) {
            debugPrint('🎬 SceneCommandExecutor: New command received');
            _handleCommand(payload.newRecord);
          },
        )
        .subscribe();

    _isListening = true;
    debugPrint('🎬 SceneCommandExecutor: Started successfully');

    // Also check for any pending commands on startup
    _processPendingCommands();
  }

  /// Stop listening for scene commands
  void stop() {
    if (!_isListening) {
      debugPrint('🎬 SceneCommandExecutor: Already stopped');
      return;
    }

    debugPrint('🎬 SceneCommandExecutor: Stopping...');
    _channel?.unsubscribe();
    _channel = null;
    _isListening = false;
    debugPrint('🎬 SceneCommandExecutor: Stopped successfully');
  }

  /// Check if the executor is currently listening
  bool get isListening => _isListening;

  /// Process any pending commands that were created while app was closed
  Future<void> _processPendingCommands() async {
    try {
      debugPrint('🎬 SceneCommandExecutor: Checking for pending commands...');

      final response = await supabase
          .from('scene_commands')
          .select('*')
          .eq('executed', false)
          .order('created_at');

      if (response.isEmpty) {
        debugPrint('🎬 SceneCommandExecutor: No pending commands');
        return;
      }

      debugPrint(
        '🎬 SceneCommandExecutor: Found ${response.length} pending command(s)',
      );

      for (final command in response) {
        await _handleCommand(command);
        // Small delay between commands
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint(
        '🎬 SceneCommandExecutor: Error processing pending commands: $e',
      );
    }
  }

  /// Handle a single scene command
  Future<void> _handleCommand(Map<String, dynamic> command) async {
    final commandId = command['id'] as String;
    final deviceId = command['device_id'] as String;
    final actionData = command['action_data'] as Map<String, dynamic>;

    // Support both 'action_type' and 'type' fields
    final actionType =
        (command['action_type'] ??
                actionData['action_type'] ??
                actionData['type'])
            as String?;

    if (actionType == null) {
      debugPrint('🎬 SceneCommandExecutor: No action_type found in command');
      await _markCommandFailed(commandId, 'Missing action_type');
      return;
    }

    debugPrint(
      '🎬 SceneCommandExecutor: Executing $actionType for device $deviceId',
    );

    try {
      // Execute based on action type
      if (actionType == 'power') {
        await _executePowerCommand(deviceId, actionData);
      } else if (actionType == 'shutter') {
        await _executeShutterCommand(deviceId, actionData);
      } else {
        debugPrint('🎬 SceneCommandExecutor: Unknown action type: $actionType');
        await _markCommandFailed(commandId, 'Unknown action type: $actionType');
        return;
      }

      // Mark command as executed
      await _markCommandExecuted(commandId);
      debugPrint(
        '🎬 SceneCommandExecutor: Command $commandId executed successfully',
      );
    } catch (e) {
      debugPrint(
        '🎬 SceneCommandExecutor: Error executing command $commandId: $e',
      );
      await _markCommandFailed(commandId, e.toString());
    }
  }

  /// Execute a power command (relay/dimmer)
  Future<void> _executePowerCommand(
    String deviceId,
    Map<String, dynamic> actionData,
  ) async {
    final channels = List<int>.from(actionData['channels'] ?? [1]);
    final state = actionData['state'] as bool? ?? true;

    debugPrint(
      '🎬 SceneCommandExecutor: Setting channels ${channels.join(", ")} to ${state ? "ON" : "OFF"}',
    );

    // Fetch device to check total channels
    final deviceResponse = await supabase
        .from('devices')
        .select('channel_count')
        .eq('id', deviceId)
        .single();

    final totalChannels = deviceResponse['channel_count'] as int? ?? 1;

    // Optimize: If controlling all channels, use POWER0 command
    if (channels.length == totalChannels && channels.length > 1) {
      debugPrint('🎬 SceneCommandExecutor: Using POWER0 for all channels');
      await _mqttDeviceManager.setBulkPower(deviceId, state);
    } else {
      // Send power command for each channel individually
      for (final channel in channels) {
        await _mqttDeviceManager.setChannelPower(deviceId, channel, state);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Execute a shutter command
  Future<void> _executeShutterCommand(
    String deviceId,
    Map<String, dynamic> actionData,
  ) async {
    final position = actionData['position'] as int? ?? 50;

    debugPrint(
      '🎬 SceneCommandExecutor: Setting shutter position to $position%',
    );

    // Assuming shutter index 1 (most common case)
    await _enhancedMqttService.setShutterPosition(deviceId, 1, position);
  }

  /// Mark a command as executed
  Future<void> _markCommandExecuted(String commandId) async {
    try {
      await supabase
          .from('scene_commands')
          .update({
            'executed': true,
            'executed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commandId);
    } catch (e) {
      debugPrint(
        '🎬 SceneCommandExecutor: Error marking command as executed: $e',
      );
    }
  }

  /// Mark a command as failed
  Future<void> _markCommandFailed(String commandId, String errorMessage) async {
    try {
      await supabase
          .from('scene_commands')
          .update({
            'executed': true,
            'executed_at': DateTime.now().toIso8601String(),
            'error_message': errorMessage,
          })
          .eq('id', commandId);
    } catch (e) {
      debugPrint(
        '🎬 SceneCommandExecutor: Error marking command as failed: $e',
      );
    }
  }
}
